# AZURE DEPLOYMENT GUIDE

**Complete step-by-step guide to deploy production contact center on Azure**

---

## 📋 TABLE OF CONTENTS

1. [Prerequisites](#prerequisites)
2. [Preparation](#preparation)
3. [Azure Setup](#azure-setup)
4. [Terraform Deployment](#terraform-deployment)
5. [Kubernetes Configuration](#kubernetes-configuration)
6. [Application Deployment](#application-deployment)
7. [Verification](#verification)
8. [CI/CD Setup](#cicd-setup)
9. [Operations](#operations)

---

## PREREQUISITES

### Required Software
```bash
# Check versions
az --version       # azure-cli/2.50+
terraform --version # 1.5+
kubectl version --client # 1.27+
helm version       # 3.12+
psql --version     # postgres 13+
git --version      # 2.40+
```

### Required Accounts
- ✅ Azure Free Tier Account (https://azure.microsoft.com/free/)
- ✅ GitHub Account (for CI/CD)
- ✅ Local terminal with bash

### Knowledge Requirements
- Basic understanding of cloud architecture
- Kubernetes concepts (pods, deployments, services)
- Terraform and Infrastructure as Code
- PostgreSQL databases

---

## PREPARATION

### Step 1: Clone/Navigate to Project
```bash
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/AZURE_DEPLOYMENT

# Verify structure
ls -la
# Should show:
# - 00_PLANNING/
# - 01_INFRASTRUCTURE/
# - 07_CI_CD/
# - 09_DOCUMENTATION/
# - 12_DEPLOYMENT_SCRIPTS/
```

### Step 2: Review Documentation
```bash
# Quick start
cat QUICK_START.md

# Understanding free tier
cat 00_PLANNING/free_tier_strategy.md

# Full setup guide
cat 09_DOCUMENTATION/SETUP_AZURE.md
```

### Step 3: Prepare Azure Account
```bash
# Login to Azure
az login
# Opens browser to authenticate

# Verify authentication
az account show
# Should show your account details

# List subscriptions
az account list --output table
```

---

## AZURE SETUP

### Step 1: Get Subscription ID
```bash
# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Your Subscription ID: $SUBSCRIPTION_ID"

# Save for later
export SUBSCRIPTION_ID=$SUBSCRIPTION_ID
```

### Step 2: Create Service Principal for Terraform
```bash
# Generate credentials (optional, for CI/CD)
az ad sp create-for-rbac \
  --name "terraform-deployment" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID"

# Output: Save the appId, password, and tenant ID
# These will be used for GitHub Actions authentication
```

### Step 3: Verify Permissions
```bash
# Check current user permissions
az role assignment list \
  --assignee "$(az account show --query 'user.name' -o tsv)" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Should show: Contributor or Owner role
```

---

## TERRAFORM DEPLOYMENT

### Step 1: Configure Variables
```bash
cd 01_INFRASTRUCTURE/terraform

# Edit terraform.tfvars
cat > terraform.tfvars << EOF
subscription_id = "$SUBSCRIPTION_ID"
project_name = "safaricom-cc"
environment = "production"
azure_region = "eastus"

# Networking
vnet_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
database_subnet_cidr = "10.0.3.0/24"

# Database
db_admin_username = "psqladmin"
db_name = "safaricom_cc"
db_sku_name = "B_Standard_B1s"  # Free tier
db_storage_mb = 32768

# Kubernetes
k8s_version = "1.27"
aks_vm_size = "Standard_B2s"    # Free tier
aks_node_count = 3
aks_min_count = 3
aks_max_count = 5

# Tags
common_tags = {
  Environment = "production"
  Project = "SafaricomCC"
  ManagedBy = "Terraform"
  CreatedDate = "2026-05-20"
}
EOF

cat terraform.tfvars
```

### Step 2: Initialize Terraform
```bash
# Download providers and modules
terraform init

# Verify initialization
terraform validate
# Should show: Success!
```

### Step 3: Plan Infrastructure
```bash
# Generate plan
terraform plan -out=tfplan

# Review plan
terraform show tfplan

# Should show resources to be created:
# - azurerm_resource_group
# - azurerm_virtual_network
# - azurerm_kubernetes_cluster
# - azurerm_postgresql_flexible_server
# - etc.
```

### Step 4: Apply Infrastructure
```bash
# Deploy infrastructure
terraform apply tfplan
# Takes 10-15 minutes

# Monitor progress:
watch -n 5 'az group show --name safaricom-cc-production-rg --query "{Status: provisioningState}"'
```

### Step 5: Retrieve Outputs
```bash
# Get all outputs
terraform output

# Or save to JSON
terraform output -json > outputs.json
cat outputs.json

# Extract specific values
AKS_CLUSTER=$(terraform output -raw aks_cluster_name)
POSTGRES_FQDN=$(terraform output -raw postgresql_fqdn)
ACR_SERVER=$(terraform output -raw acr_login_server)

echo "AKS Cluster: $AKS_CLUSTER"
echo "PostgreSQL: $POSTGRES_FQDN"
echo "ACR: $ACR_SERVER"
```

---

## KUBERNETES CONFIGURATION

### Step 1: Get Cluster Credentials
```bash
# Get kubeconfig
az aks get-credentials \
  --resource-group safaricom-cc-production-rg \
  --name $(terraform output -raw aks_cluster_name) \
  --overwrite-existing

# Verify connection
kubectl cluster-info
# Should show cluster information

kubectl get nodes
# Should show 3 nodes
```

### Step 2: Create Namespaces
```bash
# Create namespaces
kubectl create namespace safaricom-cc
kubectl create namespace monitoring
kubectl create namespace ingress

# Verify
kubectl get namespaces
```

### Step 3: Apply RBAC and Policies
```bash
cd ../../04_KUBERNETES/manifests

# Apply RBAC
kubectl apply -f rbac.yaml

# Apply network policies
kubectl apply -f network-policy.yaml

# Verify
kubectl get rolebinding -n safaricom-cc
kubectl get networkpolicy -n safaricom-cc
```

---

## APPLICATION DEPLOYMENT

### Step 1: Setup Database
```bash
# Get database connection info
POSTGRES_FQDN=$(cd ../01_INFRASTRUCTURE/terraform && terraform output -raw postgresql_fqdn)
POSTGRES_PASSWORD=$(cd ../01_INFRASTRUCTURE/terraform && terraform output -raw db_password)

export PGPASSWORD=$POSTGRES_PASSWORD

# Wait for PostgreSQL to be ready
for i in {1..30}; do
  if psql -h $POSTGRES_FQDN -U psqladmin -d safaricom_cc -c "SELECT 1" &>/dev/null; then
    echo "PostgreSQL is ready!"
    break
  fi
  echo "Waiting for PostgreSQL... ($i/30)"
  sleep 10
done

# Create schema
psql -h $POSTGRES_FQDN -U psqladmin -d safaricom_cc -f ../../02_DATABASE/schema/01_create_tables.sql
psql -h $POSTGRES_FQDN -U psqladmin -d safaricom_cc -f ../../02_DATABASE/schema/02_create_indexes.sql
psql -h $POSTGRES_FQDN -U psqladmin -d safaricom_cc -f ../../02_DATABASE/schema/03_create_views.sql

# Verify schema
psql -h $POSTGRES_FQDN -U psqladmin -d safaricom_cc -c "\dt"
```

### Step 2: Deploy Applications with Helm
```bash
cd ../04_KUBERNETES/helm

# Add repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Deploy Contact Center
helm upgrade --install safaricom-cc . \
  --namespace safaricom-cc \
  -f values-production.yaml \
  --wait \
  --timeout 10m

# Deploy Prometheus
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --wait

# Deploy Grafana
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --wait
```

---

## VERIFICATION

### Step 1: Check Cluster Health
```bash
# All nodes should be Ready
kubectl get nodes
# Expected: All nodes in Ready state

# All pods should be Running
kubectl get pods -A
# Expected: All in Running or Succeeded state

# Services should have endpoints
kubectl get svc -A
# Expected: All services have EXTERNAL-IP or ClusterIP
```

### Step 2: Verify Database
```bash
# Check database connectivity
psql -h $POSTGRES_FQDN \
  -U psqladmin \
  -d safaricom_cc \
  -c "SELECT version();"

# Check tables created
psql -h $POSTGRES_FQDN \
  -U psqladmin \
  -d safaricom_cc \
  -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';"
```

### Step 3: Access Monitoring
```bash
# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "Grafana Password: $GRAFANA_PASSWORD"

# Port forward to local
kubectl port-forward -n monitoring svc/grafana 3000:80 &

# Access in browser
# http://localhost:3000
# Username: admin
# Password: (from above)
```

---

## CI/CD SETUP

### Step 1: Initialize Git Repository
```bash
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/AZURE_DEPLOYMENT

# Initialize git
git init
git add .
git commit -m "Initial Azure deployment"

# Create .gitignore
cat > .gitignore << EOF
# Terraform
*.tfstate
*.tfstate.*
.terraform/
tfplan
.env
EOF
```

### Step 2: Create GitHub Repository
```bash
# Go to GitHub
# Create new repository: azure-contact-center

# Add remote
git remote add origin https://github.com/YOUR_USERNAME/azure-contact-center.git
git branch -M main
git push -u origin main
```

### Step 3: Configure GitHub Secrets
```bash
# Go to GitHub Repo → Settings → Secrets and variables → Actions
# Add these secrets:

# AZURE_SUBSCRIPTION_ID - Your subscription ID from az account show
# AZURE_TENANT_ID - From service principal output
# AZURE_CLIENT_ID - From service principal output
# AZURE_CLIENT_SECRET - From service principal output

# Or use service principal JSON:
# AZURE_CREDENTIALS - Full service principal JSON

# Test workflow:
# Go to Actions tab
# Should see workflows running on push
```

### Step 4: Verify CI/CD Workflows
```bash
# Check workflow status on GitHub
# Actions → terraform-plan, terraform-apply, helm-deploy

# Monitor deployments
# Actions tab should show successful runs

# Check deployed versions
kubectl rollout history deployment/safaricom-cc -n safaricom-cc
```

---

## OPERATIONS

### Daily Operations

#### Monitor Costs
```bash
# Check daily spend
az costmanagement query \
  --subscription "$SUBSCRIPTION_ID" \
  --timeframe MonthToDate \
  --granularity Daily
```

#### Check System Health
```bash
# Pod status
kubectl get pods -A

# Node status
kubectl get nodes

# Service status
kubectl get svc -A

# Logs
kubectl logs -n safaricom-cc -l app=safaricom-cc --tail=50
```

#### Scale Applications
```bash
# Scale deployments
kubectl scale deployment safaricom-cc -n safaricom-cc --replicas=5

# Check auto-scaling
kubectl get hpa -n safaricom-cc
```

### Weekly Operations

#### Database Backups
```bash
# PostgreSQL backups are automatic (30-day retention)
# Check backup status
az postgres flexible-server restore-point-in-time list \
  --name safaricom-cc-production-postgres \
  --resource-group safaricom-cc-production-rg
```

#### Update Applications
```bash
# Update via CI/CD
git commit -m "Update application version"
git push origin main
# GitHub Actions automatically deploys!

# Or manual update
helm upgrade safaricom-cc ./04_KUBERNETES/helm \
  --namespace safaricom-cc
```

### Emergency Procedures

#### Rollback Deployment
```bash
# If something breaks
helm rollback safaricom-cc 0 -n safaricom-cc

# Or via Kubernetes
kubectl rollout undo deployment/safaricom-cc -n safaricom-cc
```

#### Recover from Disaster
```bash
# Database restore from backup
az postgres flexible-server restore \
  --name safaricom-cc-production-postgres \
  --resource-group safaricom-cc-production-rg \
  --restore-time "2026-05-19 12:00:00"

# Terraform state recovery
terraform refresh
```

---

## CLEANUP

### Remove All Resources
```bash
cd 01_INFRASTRUCTURE/terraform

# Plan destruction
terraform plan -destroy

# Destroy all resources
terraform destroy
# Press 'yes' to confirm

# Verify cleanup
az group show --name safaricom-cc-production-rg
# Should show: NotFound (after a few minutes)
```

---

## NEXT STEPS

1. ✅ Complete basic deployment
2. ✅ Practice with Helm deployments
3. ✅ Understand Terraform configuration
4. ✅ Use CI/CD for updates
5. ✅ Monitor costs and performance
6. ✅ Simulate failure scenarios
7. ✅ Practice disaster recovery

---

**Deployment Complete!** 🎉

Your production-grade contact center is now running on Azure with enterprise-level CI/CD automation.
