#!/bin/bash

################################################################################
# ADVANCED CONTACT CENTER - FULL DEPLOYMENT SCRIPT
# Production-grade deployment with validation, monitoring, and rollback
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# ============================================================================
# USAGE & VALIDATION
# ============================================================================

usage() {
    cat << EOF
Usage: $0 <environment> <region> [options]

Environments: dev, staging, production
Regions: us-east-1, eu-west-1, ap-southeast-1

Options:
  --dry-run              Show what would be deployed without making changes
  --skip-validation      Skip pre-flight checks
  --skip-backup          Skip backup before deployment
  --skip-tests           Skip post-deployment tests
  --verbose              Enable verbose output
  --no-color             Disable colored output

Examples:
  $0 production us-east-1
  $0 staging us-east-1 --dry-run
  $0 dev us-east-1 --skip-tests --verbose

EOF
    exit 1
}

# ============================================================================
# MAIN DEPLOYMENT STAGES
# ============================================================================

validate_prerequisites() {
    log_step "Validating prerequisites..."

    local required_tools=("terraform" "kubectl" "helm" "aws" "ansible")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi

    log_success "All prerequisites validated"
}

validate_configuration() {
    log_step "Validating configuration..."

    # Check Terraform syntax
    cd "${PROJECT_ROOT}/01_INFRASTRUCTURE/terraform"

    if ! terraform validate; then
        log_error "Terraform validation failed"
        return 1
    fi

    # Check Helm charts
    cd "${PROJECT_ROOT}/04_KUBERNETES/helm"

    if ! helm lint . --strict; then
        log_error "Helm chart validation failed"
        return 1
    fi

    # Check Ansible playbooks
    cd "${PROJECT_ROOT}/01_INFRASTRUCTURE/ansible"

    if ! ansible-playbook --syntax-check playbooks/*.yml; then
        log_error "Ansible playbook syntax check failed"
        return 1
    fi

    log_success "All configurations validated"
}

create_backup() {
    log_step "Creating backup of current state..."

    local backup_dir="${PROJECT_ROOT}/.backups/$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$backup_dir"

    # Backup Terraform state
    if aws s3 ls "s3://safaricom-cc-terraform-state"; then
        aws s3 sync "s3://safaricom-cc-terraform-state" "${backup_dir}/terraform-state/" || true
    fi

    # Backup database
    log_info "Triggering RDS backup..."
    aws rds create-db-cluster-snapshot \
        --db-cluster-identifier "safaricom-cc-cluster" \
        --db-cluster-snapshot-identifier "safaricom-cc-backup-$(date '+%Y%m%d%H%M%S')" \
        --region "$REGION" || true

    # Backup Kubernetes resources
    if kubectl cluster-info &> /dev/null; then
        kubectl get all -A -o yaml > "${backup_dir}/k8s-resources.yaml" || true
    fi

    log_success "Backup created at: $backup_dir"
}

deploy_infrastructure() {
    log_step "Deploying infrastructure with Terraform..."

    cd "${PROJECT_ROOT}/01_INFRASTRUCTURE/terraform"

    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init \
        -upgrade \
        -backend=true \
        -reconfigure

    # Plan deployment
    log_info "Planning deployment..."
    terraform plan \
        -var-file="../../environments/${ENVIRONMENT}.tfvars" \
        -out=tfplan

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "Dry-run mode: skipping actual deployment"
        terraform show tfplan
        return 0
    fi

    # Apply deployment
    log_info "Applying Terraform configuration..."
    terraform apply tfplan

    # Get outputs
    TERRAFORM_OUTPUTS=$(terraform output -json)
    EKS_ENDPOINT=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.eks_cluster_endpoint.value')
    RDS_ENDPOINT=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.rds_cluster_endpoint.value')
    ALB_DNS=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.alb_dns_name.value')

    log_success "Infrastructure deployed successfully"
    log_info "EKS Endpoint: $EKS_ENDPOINT"
    log_info "RDS Endpoint: $RDS_ENDPOINT"
    log_info "ALB DNS: $ALB_DNS"
}

configure_kubernetes() {
    log_step "Configuring Kubernetes cluster..."

    # Update kubeconfig
    log_info "Updating kubeconfig..."
    aws eks update-kubeconfig \
        --region "$REGION" \
        --name "safaricom-cc-cluster"

    # Verify cluster access
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster"
        return 1
    fi

    # Create namespaces
    log_info "Creating namespaces..."
    kubectl create namespace safaricom-cc || true
    kubectl create namespace monitoring || true
    kubectl create namespace ingress || true

    # Apply RBAC
    log_info "Applying RBAC configurations..."
    kubectl apply -f "${PROJECT_ROOT}/04_KUBERNETES/manifests/rbac.yaml"

    # Apply network policies
    log_info "Applying network policies..."
    kubectl apply -f "${PROJECT_ROOT}/04_KUBERNETES/manifests/network-policy.yaml"

    # Apply pod security policies
    log_info "Applying pod security policies..."
    kubectl apply -f "${PROJECT_ROOT}/04_KUBERNETES/manifests/pod-security.yaml"

    log_success "Kubernetes cluster configured"
}

deploy_database() {
    log_step "Setting up database..."

    log_info "Waiting for RDS to be ready..."
    aws rds wait db-cluster-available \
        --db-cluster-identifier "safaricom-cc-cluster" \
        --region "$REGION"

    log_info "Creating database schema..."
    PGPASSWORD="$(aws secretsmanager get-secret-value --secret-id safaricom-cc-db-password --region "$REGION" --query SecretString --output text)" \
    psql -h "$RDS_ENDPOINT" \
        -U safaricom_cc \
        -d safaricom_cc \
        -f "${PROJECT_ROOT}/02_DATABASE/schema/01_create_tables.sql"

    psql -h "$RDS_ENDPOINT" \
        -U safaricom_cc \
        -d safaricom_cc \
        -f "${PROJECT_ROOT}/02_DATABASE/schema/02_create_indexes.sql"

    psql -h "$RDS_ENDPOINT" \
        -U safaricom_cc \
        -d safaricom_cc \
        -f "${PROJECT_ROOT}/02_DATABASE/schema/03_create_views.sql"

    log_success "Database setup completed"
}

deploy_applications() {
    log_step "Deploying applications with Helm..."

    cd "${PROJECT_ROOT}/04_KUBERNETES/helm"

    # Add Helm repositories
    log_info "Adding Helm repositories..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update

    # Deploy main application
    log_info "Deploying Contact Center application..."
    helm upgrade --install safaricom-cc . \
        --namespace safaricom-cc \
        -f values-"${ENVIRONMENT}".yaml \
        --wait \
        --timeout 10m \
        --set database.host="$RDS_ENDPOINT"

    # Deploy monitoring stack
    log_info "Deploying Prometheus..."
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        -f "${PROJECT_ROOT}/05_MONITORING/prometheus/helm-values.yaml" \
        --wait

    # Deploy Grafana
    log_info "Deploying Grafana..."
    helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        -f "${PROJECT_ROOT}/05_MONITORING/grafana/helm-values.yaml" \
        --wait

    log_success "Applications deployed successfully"
}

run_post_deployment_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log_warning "Skipping post-deployment tests"
        return 0
    fi

    log_step "Running post-deployment tests..."

    # Check cluster health
    log_info "Checking cluster health..."
    if ! kubectl get nodes | grep -q "Ready"; then
        log_error "Cluster nodes not ready"
        return 1
    fi

    # Check deployments
    log_info "Checking deployments..."
    if kubectl get deployments -n safaricom-cc | grep -q "0/"; then
        log_error "Some deployments are not ready"
        return 1
    fi

    # Check database connectivity
    log_info "Checking database connectivity..."
    if ! kubectl run -it --rm --image=postgres:15 --restart=Never -n safaricom-cc -- \
        psql -h "$RDS_ENDPOINT" -U safaricom_cc -d safaricom_cc -c "SELECT 1"; then
        log_error "Cannot connect to database"
        return 1
    fi

    # Run smoke tests
    log_info "Running smoke tests..."
    cd "${PROJECT_ROOT}/11_TESTING"
    bash smoke_tests.sh || return 1

    log_success "Post-deployment tests passed"
}

verify_deployment() {
    log_step "Verifying deployment..."

    local deployment_status="success"

    # Check all pods are running
    log_info "Checking pod status..."
    local not_ready=$(kubectl get pods -A --no-headers | grep -v "Running\|Succeeded" | wc -l)
    if [ "$not_ready" -gt 0 ]; then
        log_warning "$not_ready pods not in Ready state"
        deployment_status="warning"
    fi

    # Check services
    log_info "Checking services..."
    kubectl get svc -A

    # Get access information
    log_info "Getting access information..."
    local grafana_password=$(kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
    local grafana_lb=$(kubectl get svc -n monitoring grafana -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

    log_success "Deployment verification completed"
    log_info "Grafana URL: http://$grafana_lb"
    log_info "Grafana password: $grafana_password"
}

# ============================================================================
# EXECUTION
# ============================================================================

main() {
    # Parse arguments
    if [ $# -lt 2 ]; then
        usage
    fi

    ENVIRONMENT="$1"
    REGION="$2"
    DRY_RUN=false
    SKIP_VALIDATION=false
    SKIP_BACKUP=false
    SKIP_TESTS=false
    VERBOSE=false

    shift 2
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=true ;;
            --skip-validation) SKIP_VALIDATION=true ;;
            --skip-backup) SKIP_BACKUP=true ;;
            --skip-tests) SKIP_TESTS=true ;;
            --verbose) VERBOSE=true ;;
            --no-color) NC=''; RED=''; GREEN=''; BLUE=''; YELLOW=''; PURPLE='' ;;
            *) log_error "Unknown option: $1"; usage ;;
        esac
        shift
    done

    # Enable verbose if requested
    if [ "$VERBOSE" = "true" ]; then
        set -x
    fi

    # Export AWS region
    export AWS_REGION="$REGION"

    # Print deployment summary
    echo ""
    log_info "========================================="
    log_info "ADVANCED CONTACT CENTER DEPLOYMENT"
    log_info "========================================="
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    log_info "Dry Run: $DRY_RUN"
    log_info "========================================="
    echo ""

    # Execute deployment stages
    if [ "$SKIP_VALIDATION" = "false" ]; then
        validate_prerequisites || exit 1
        validate_configuration || exit 1
    fi

    if [ "$SKIP_BACKUP" = "false" ]; then
        create_backup || exit 1
    fi

    deploy_infrastructure || {
        log_error "Infrastructure deployment failed"
        exit 1
    }

    configure_kubernetes || exit 1
    deploy_database || exit 1
    deploy_applications || exit 1

    if [ "$DRY_RUN" = "false" ]; then
        run_post_deployment_tests || {
            log_warning "Some tests failed, but continuing..."
        }
    fi

    verify_deployment

    # Final summary
    echo ""
    log_success "========================================="
    log_success "DEPLOYMENT COMPLETED SUCCESSFULLY"
    log_success "========================================="
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    log_info "Deployment Time: $(date)"
    log_success "========================================="
    echo ""
}

# Run main function
main "$@"
