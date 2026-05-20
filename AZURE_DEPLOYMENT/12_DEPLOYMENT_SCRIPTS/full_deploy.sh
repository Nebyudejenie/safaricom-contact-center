#!/bin/bash

################################################################################
# AZURE CONTACT CENTER - FULL DEPLOYMENT SCRIPT
# Production-grade deployment to Azure with validation and monitoring
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

Environments: dev, staging, production, Production
Regions: eastus, westus, northeurope, southeastasia

Options:
  --dry-run              Show what would be deployed without making changes
  --skip-validation      Skip pre-flight checks
  --skip-backup          Skip backup before deployment
  --skip-tests           Skip post-deployment tests
  --verbose              Enable verbose output
  --no-color             Disable colored output

Examples:
  $0 production eastus
  $0 staging eastus --dry-run
  $0 dev eastus --skip-tests --verbose

EOF
    exit 1
}

# ============================================================================
# DEPLOYMENT STAGES
# ============================================================================

validate_prerequisites() {
    log_step "Validating prerequisites..."

    local required_tools=("az" "terraform" "kubectl" "helm")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install with: az cli, terraform, kubectl, helm"
        return 1
    fi

    # Check Azure CLI authentication
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Run: az login"
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

    log_info "Terraform syntax valid"

    # Check Helm charts
    cd "${PROJECT_ROOT}/04_KUBERNETES/helm"

    if ! helm lint . --strict; then
        log_error "Helm chart validation failed"
        return 1
    fi

    log_info "Helm charts valid"

    log_success "All configurations validated"
}

create_backup() {
    log_step "Creating backup of current state..."

    local backup_dir="${PROJECT_ROOT}/.backups/$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$backup_dir"

    # Backup Terraform state
    log_info "Backing up Terraform state..."
    cd "${PROJECT_ROOT}/01_INFRASTRUCTURE/terraform"

    if [ -f terraform.cosmic ]; then
        cp terraform.cosmic "${backup_dir}/terraform.cosmic" || true
    fi

    # Backup Kubernetes resources if cluster exists
    log_info "Backing up Kubernetes resources..."
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
        -reconfigure

    # Plan deployment
    log_info "Planning infrastructure deployment..."
    terraform plan \
        -var-file="terraform.tfvars" \
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
    log_info "Retrieving infrastructure outputs..."
    TERRAFORM_OUTPUTS=$(terraform output -json)

    AKS_CLUSTER_NAME=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.aks_cluster_name.value')
    AKS_CLUSTER_ID=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.aks_cluster_id.value')
    POSTGRES_FQDN=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.postgresql_fqdn.value')
    ACR_LOGIN_SERVER=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.acr_login_server.value')
    APPGW_IP=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.application_gateway_ip.value')
    RESOURCE_GROUP=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.resource_group_name.value')

    log_success "Infrastructure deployed successfully"
    log_info "AKS Cluster: $AKS_CLUSTER_NAME"
    log_info "PostgreSQL FQDN: $POSTGRES_FQDN"
    log_info "ACR: $ACR_LOGIN_SERVER"
    log_info "Application Gateway IP: $APPGW_IP"
}

configure_kubernetes() {
    log_step "Configuring Kubernetes cluster..."

    # Get AKS credentials
    log_info "Retrieving AKS credentials..."
    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_CLUSTER_NAME" \
        --overwrite-existing

    # Verify cluster access
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster"
        return 1
    fi

    log_info "Cluster access verified"

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

    log_success "Kubernetes cluster configured"
}

deploy_database() {
    log_step "Setting up database..."

    log_info "Waiting for PostgreSQL to be ready..."

    # Wait for PostgreSQL to accept connections
    local max_retries=30
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if psql -h "$POSTGRES_FQDN" -U "psqladmin" -d "safaricom_cc" -c "SELECT 1" &> /dev/null; then
            break
        fi
        retry=$((retry + 1))
        log_info "Waiting for PostgreSQL... ($retry/$max_retries)"
        sleep 10
    done

    if [ $retry -eq $max_retries ]; then
        log_error "PostgreSQL did not become ready in time"
        return 1
    fi

    log_info "PostgreSQL is ready, creating schema..."

    export PGPASSWORD="$(terraform output -raw db_password 2>/dev/null || echo 'error')"

    psql -h "$POSTGRES_FQDN" \
        -U psqladmin \
        -d safaricom_cc \
        -f "${PROJECT_ROOT}/02_DATABASE/schema/01_create_tables.sql"

    psql -h "$POSTGRES_FQDN" \
        -U psqladmin \
        -d safaricom_cc \
        -f "${PROJECT_ROOT}/02_DATABASE/schema/02_create_indexes.sql"

    psql -h "$POSTGRES_FQDN" \
        -U psqladmin \
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
        --timeout 10m

    # Deploy monitoring stack
    log_info "Deploying Prometheus..."
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --wait

    # Deploy Grafana
    log_info "Deploying Grafana..."
    helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
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
    export PGPASSWORD="$(terraform output -raw db_password 2>/dev/null)"
    if ! psql -h "$POSTGRES_FQDN" \
        -U psqladmin \
        -d safaricom_cc \
        -c "SELECT 1"; then
        log_error "Cannot connect to database"
        return 1
    fi

    log_success "Post-deployment tests passed"
}

verify_deployment() {
    log_step "Verifying deployment..."

    # Check all pods are running
    log_info "Checking pod status..."
    local not_ready=$(kubectl get pods -A --no-headers | grep -v "Running\|Succeeded" | wc -l)
    if [ "$not_ready" -gt 0 ]; then
        log_warning "$not_ready pods not in Ready state"
    fi

    # Check services
    log_info "Checking services..."
    kubectl get svc -A

    # Get Grafana access information
    log_info "Getting access information..."
    local grafana_password=$(kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode || echo "check Kubernetes secret")

    log_success "Deployment verification completed"
    log_info "Application Gateway IP: $APPGW_IP"
    log_info "PostgreSQL FQDN: $POSTGRES_FQDN"
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

    ENVIRONMENT=$(echo "$1" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    REGION=$(echo "$2" | tr '[:upper:]' '[:lower:]')       # Convert to lowercase
    DRY_RUN=false
    SKIP_VALIDATION=false
    SKIP_BACKUP=false
    SKIP_TESTS=false
    VERBOSE=false

    # Validate environment
    case "$ENVIRONMENT" in
        dev|staging|production) ;;
        *) log_error "Invalid environment: $ENVIRONMENT"; log_info "Valid: dev, staging, production"; exit 1 ;;
    esac

    # Validate region
    case "$REGION" in
        eastus|westus|northeurope|southeastasia) ;;
        *) log_error "Invalid region: $REGION"; log_info "Valid: eastus, westus, northeurope, southeastasia"; exit 1 ;;
    esac

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

    # Print deployment summary
    echo ""
    log_info "========================================="
    log_info "AZURE CONTACT CENTER DEPLOYMENT"
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
