#!/bin/bash

# SAFARICOM CONTACT CENTER - DEPLOYMENT SCRIPT
# Usage: ./deploy.sh [local|kubernetes|terraform]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    case "$1" in
        local)
            if ! command -v docker &> /dev/null; then
                log_error "Docker is not installed"
                exit 1
            fi
            if ! command -v docker-compose &> /dev/null; then
                log_error "Docker Compose is not installed"
                exit 1
            fi
            log_success "Docker and Docker Compose found"
            ;;
        kubernetes)
            if ! command -v kubectl &> /dev/null; then
                log_error "kubectl is not installed"
                exit 1
            fi
            if ! kubectl cluster-info &> /dev/null; then
                log_error "Kubernetes cluster not accessible"
                exit 1
            fi
            log_success "Kubernetes cluster found"
            ;;
        terraform)
            if ! command -v terraform &> /dev/null; then
                log_error "Terraform is not installed"
                exit 1
            fi
            if ! command -v aws &> /dev/null; then
                log_error "AWS CLI is not installed"
                exit 1
            fi
            log_success "Terraform and AWS CLI found"
            ;;
    esac
}

# LOCAL DEPLOYMENT
deploy_local() {
    log_info "========================================="
    log_info "Deploying Contact Center (Local)"
    log_info "========================================="

    check_prerequisites "local"

    log_info "Starting Docker Compose services..."
    docker-compose up -d

    log_info "Waiting for services to be ready..."
    sleep 10

    # Check database
    log_info "Checking database connectivity..."
    docker-compose exec -T postgres-primary pg_isready -U cc_user -d safaricom_cc

    log_success "Contact Center deployed locally!"

    log_info ""
    log_info "========================================="
    log_info "ACCESS INFORMATION"
    log_info "========================================="
    log_info "Database: localhost:5432"
    log_info "  Username: cc_user"
    log_info "  Database: safaricom_cc"
    log_info ""
    log_info "IVR (FreeSWITCH):"
    log_info "  SIP Port: 5060 (UDP)"
    log_info "  ESL Port: 8021 (TCP)"
    log_info ""
    log_info "Monitoring:"
    log_info "  Prometheus: http://localhost:9090"
    log_info "  Grafana: http://localhost:3000 (admin/admin123)"
    log_info ""
    log_info "Load Balancer: http://localhost"
    log_info ""
    log_info "View logs: docker-compose logs -f [service]"
    log_info "Stop system: docker-compose down"
    log_info "========================================="
}

# KUBERNETES DEPLOYMENT
deploy_kubernetes() {
    log_info "========================================="
    log_info "Deploying Contact Center (Kubernetes)"
    log_info "========================================="

    check_prerequisites "kubernetes"

    log_info "Creating namespace..."
    kubectl create namespace safaricom-cc || log_warning "Namespace already exists"

    log_info "Applying Kubernetes manifests..."
    kubectl apply -f kubernetes/deployment.yaml

    log_info "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/postgres-primary -n safaricom-cc || true

    kubectl wait --for=condition=available --timeout=300s \
        deployment/ivr -n safaricom-cc || true

    log_success "Contact Center deployed to Kubernetes!"

    log_info ""
    log_info "========================================="
    log_info "KUBERNETES ACCESS INFORMATION"
    log_info "========================================="

    # Get Grafana NodePort
    GRAFANA_PORT=$(kubectl get svc grafana -n safaricom-cc -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30300")

    log_info "Grafana: http://NODE_IP:$GRAFANA_PORT"
    log_info "  Username: admin"
    log_info "  Password: admin123"
    log_info ""
    log_info "Database Service: postgres-primary.safaricom-cc.svc.cluster.local:5432"
    log_info "IVR Service: ivr-service.safaricom-cc.svc.cluster.local:5060"
    log_info "Redis Service: redis.safaricom-cc.svc.cluster.local:6379"
    log_info ""
    log_info "View deployments:"
    log_info "  kubectl get all -n safaricom-cc"
    log_info ""
    log_info "View logs:"
    log_info "  kubectl logs -f deployment/ivr -n safaricom-cc"
    log_info ""
    log_info "Port forward Grafana (local access):"
    log_info "  kubectl port-forward -n safaricom-cc svc/grafana 3000:3000"
    log_info "========================================="
}

# TERRAFORM DEPLOYMENT
deploy_terraform() {
    log_info "========================================="
    log_info "Deploying Contact Center (Terraform/AWS)"
    log_info "========================================="

    check_prerequisites "terraform"

    cd 01_INFRASTRUCTURE/terraform || exit 1

    log_info "Initializing Terraform..."
    terraform init

    log_info "Validating configuration..."
    terraform validate

    log_info "Planning deployment..."
    terraform plan -out=tfplan

    log_warning "Review the plan above and confirm to continue"
    read -p "Continue with deployment? (yes/no) " -n 3 -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Applying Terraform configuration..."
        terraform apply tfplan

        log_success "Contact Center infrastructure deployed to AWS!"

        log_info ""
        log_info "========================================="
        log_info "AWS INFRASTRUCTURE DEPLOYED"
        log_info "========================================="
        log_info "Outputs:"
        terraform output
        log_info "========================================="
    else
        log_warning "Deployment cancelled"
        rm -f tfplan
    fi

    cd - > /dev/null
}

# TESTING
run_tests() {
    log_info "Running tests..."

    if [ -f "06_TESTING/integration_test.sh" ]; then
        bash 06_TESTING/integration_test.sh
    else
        log_warning "Test script not found"
    fi
}

# CLEANUP
cleanup_local() {
    log_warning "Cleaning up local deployment..."
    docker-compose down -v
    log_success "Local deployment cleaned up"
}

cleanup_kubernetes() {
    log_warning "Cleaning up Kubernetes deployment..."
    kubectl delete namespace safaricom-cc
    log_success "Kubernetes deployment cleaned up"
}

# MAIN
main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 [local|kubernetes|terraform|cleanup]"
        echo ""
        echo "Options:"
        echo "  local       - Deploy with Docker Compose (local testing)"
        echo "  kubernetes  - Deploy to Kubernetes cluster"
        echo "  terraform   - Deploy to AWS with Terraform"
        echo "  cleanup     - Clean up deployments"
        echo ""
        echo "Examples:"
        echo "  $0 local"
        echo "  $0 kubernetes"
        echo "  $0 terraform"
        exit 1
    fi

    case "$1" in
        local)
            deploy_local
            ;;
        kubernetes)
            deploy_kubernetes
            ;;
        terraform)
            deploy_terraform
            ;;
        cleanup)
            if [ -z "$2" ]; then
                echo "Usage: $0 cleanup [local|kubernetes|all]"
                exit 1
            fi
            case "$2" in
                local)
                    cleanup_local
                    ;;
                kubernetes)
                    cleanup_kubernetes
                    ;;
                all)
                    cleanup_local
                    cleanup_kubernetes
                    ;;
                *)
                    log_error "Unknown cleanup option: $2"
                    exit 1
                    ;;
            esac
            ;;
        test)
            run_tests
            ;;
        *)
            log_error "Unknown deployment option: $1"
            exit 1
            ;;
    esac
}

main "$@"
