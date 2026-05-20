# AZURE DEPLOYMENT SETUP GUIDE

**Time to Deploy:** 30-45 minutes  
**Complexity:** Advanced  
**Requirements:** Azure Free Tier account, Terraform, kubectl, Helm

---

## 🔐 STEP 1: PREPARE AZURE ACCOUNT

### Create Azure Account
```bash
# Visit https://azure.microsoft.com/en-us/free/
# Sign up for free tier (includes $200 credits for 30 days)
```

### Login to Azure
```bash
az login
# Opens browser to authenticate

# Verify login
az account show
```

### Get Subscription ID
```bash
az account list --query "[].{Name:name, ID:id}"

# Copy your subscription ID and save it
export SUBSCRIPTION_ID="your-subscription-id-here"
```

---

## 🛠️ STEP 2: VERIFY PREREQUISITES

### Check Required Tools
```bash
# Azure CLI
az --version
# Expected: azure-cli 2.50+

# Terraform
terraform --version
# Expected: Terraform v1.5+

# kubectl
kubectl version --client
# Expected: v1.27+

# Helm
helm version
# Expected: v3.12+
```

### Install Missing Tools
```bash
# On Linux/Mac
brew install azure-cli terraform kubectl helm

# On Windows (PowerShell)
choco install azure-cli terraform kubernetes-cli helm
```

---

## 📁 STEP 3: CONFIGURE TERRAFORM

### Update Variables
```bash
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/AZURE_DEPLOYMENT/01_INFRASTRUCTURE/terraform

# Edit terraform.tfvars
nano terraform.tfvars

# Update subscription ID
subscription_id = "YOUR_SUBSCRIPTION_ID_HERE"
```

### Create Azure Storage for State Management (Optional but Recommended)
```bash
# Create resource group for state
az group create \
  --name cosmic \
  --location eastus

# Create storage account
STORAGE_ACCOUNT_NAME="safaricomccstate$(date +%s)"
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group cosmic \
  --sku Standard_LRS

# Create container
az storage container create \
  --name terraform-state \
  --account-name "$STORAGE_ACCOUNT_NAME"

# Save these for backend.tf
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
```

### Update backend.tf with Storage Account
```bash
# Edit backend.tf
nano backend.tf

# Uncomment azurerm backend block
# Update with your storage account name from above
```

---

## 🚀 STEP 4: DEPLOY INFRASTRUCTURE

### Initialize Terraform
```bash
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/AZURE_DEPLOYMENT/01_INFRASTRUCTURE/terraform

terraform init
# Downloads providers and modules
```

### Validate Configuration
```bash
terraform validate
# Checks syntax and configuration
```

### Plan Deployment (Dry Run)
```bash
terraform plan -out=tfplan
# Shows what will be created
# Review the plan carefully!
```

### Apply Deployment
```bash
terraform apply tfplan
# Deploys infrastructure to Azure
# Takes 10-15 minutes

# Save outputs
terraform output -json > outputs.json
```

### Verify Infrastructure
```bash
# Check resource group
az group show --name safaricom-cc-production-rg

# Check AKS cluster
az aks list --resource-group safaricom-cc-production-rg

# Check PostgreSQL
az postgres flexible-server list --resource-group safaricom-cc-production-rg
```

---

## 🔗 STEP 5: CONFIGURE KUBERNETES ACCESS

### Get AKS Credentials
```bash
az aks get-credentials \
  --resource-group safaricom-cc-production-rg \
  --name safaricom-cc-production-aks \
  --overwrite-existing
```

### Verify Cluster Connection
```bash
kubectl cluster-info
# Should show cluster information

kubectl get nodes
# Should show 3 nodes running
```

### Create Namespaces
```bash
kubectl create namespace safaricom-cc
kubectl create namespace monitoring
```

---

## 🗄️ STEP 6: SETUP DATABASE SCHEMA

### Get Database Connection Info
```bash
# From Terraform outputs
POSTGRES_FQDN=$(terraform output -raw postgresql_fqdn)
DB_PASSWORD=$(terraform output -raw db_password)

echo "Database: $POSTGRES_FQDN"
```

### Create Database Schema
```bash
export PGPASSWORD="$DB_PASSWORD"

# Create tables
psql -h "$POSTGRES_FQDN" \
  -U psqladmin \
  -d safaricom_cc \
  -f ../../../02_DATABASE/schema/01_create_tables.sql

# Create indexes
psql -h "$POSTGRES_FQDN" \
  -U psqladmin \
  -d safaricom_cc \
  -f ../../../02_DATABASE/schema/02_create_indexes.sql

# Create views
psql -h "$POSTGRES_FQDN" \
  -U psqladmin \
  -d safaricom_cc \
  -f ../../../02_DATABASE/schema/03_create_views.sql

# Verify schema
psql -h "$POSTGRES_FQDN" \
  -U psqladmin \
  -d safaricom_cc \
  -c "\dt"  # List tables
```

---

## 📦 STEP 7: DEPLOY APPLICATIONS WITH HELM

### Add Helm Repositories
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Deploy Contact Center Application
```bash
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/AZURE_DEPLOYMENT/04_KUBERNETES/helm

helm upgrade --install safaricom-cc . \
  --namespace safaricom-cc \
  --create-namespace \
  -f values-production.yaml \
  --wait \
  --timeout 10m
```

### Deploy Monitoring Stack
```bash
# Prometheus
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --wait

# Grafana
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --wait
```

### Verify Deployments
```bash
# Check all pods
kubectl get pods -A

# Check services
kubectl get svc -A

# View deployment status
kubectl rollout status deployment/safaricom-cc -n safaricom-cc
```

---

## 🔍 STEP 8: VERIFY DEPLOYMENT

### Check Cluster Health
```bash
# All nodes should be Ready
kubectl get nodes

# All pods should be Running
kubectl get pods -A

# All services should have endpoints
kubectl get svc -A
```

### Access Applications

#### Grafana Dashboard
```bash
# Get Grafana password
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port forward to local
kubectl port-forward -n monitoring svc/grafana 3000:80

# Access http://localhost:3000
# Username: admin
# Password: (from above)
```

#### Prometheus
```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Access http://localhost:9090
```

#### Test Database
```bash
# Query sample data
psql -h "$POSTGRES_FQDN" \
  -U psqladmin \
  -d safaricom_cc \
  -c "SELECT COUNT(*) FROM customers;"
```

---

## 🔄 STEP 9: SETUP CI/CD WITH GITHUB ACTIONS

### Push to GitHub
```bash
# Initialize git repo
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/AZURE_DEPLOYMENT

git init
git add .
git commit -m "Initial Azure deployment with Terraform and Helm"

# Add remote
git remote add origin https://github.com/YOUR_USERNAME/REPO_NAME.git
git branch -M main
git push -u origin main
```

### Configure GitHub Secrets
```bash
# Go to GitHub repo → Settings → Secrets and variables → Actions

# Add Azure credentials
# Generate service principal:
az ad sp create-for-rbac \
  --name "GitHubActions" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID"

# Add to GitHub as AZURE_CREDENTIALS (JSON format)
# Add these separately:
# - AZURE_CLIENT_ID
# - AZURE_CLIENT_SECRET
# - AZURE_SUBSCRIPTION_ID
# - AZURE_TENANT_ID
```

### Enable Workflows
```bash
# GitHub Actions are auto-enabled
# Check Actions tab in GitHub repo
# Workflows will run on push to main and pull requests
```

---

## 💰 MONITOR COSTS

### View Azure Costs
```bash
# Daily cost analysis
az costmanagement query \
  --subscription "$SUBSCRIPTION_ID" \
  --timeframe MonthToDate
```

### Optimize for Free Tier
```bash
# Recommended settings in terraform.tfvars:
- aks_vm_size = "Standard_B2s"     # Free tier eligible
- db_sku_name = "B_Standard_B1s"   # Free tier eligible
- aks_node_count = 2               # Minimize compute
- aks_max_count = 5                # Limit auto-scale
```

---

## 🧹 STEP 10: CLEANUP (When Done)

### Destroy All Resources
```bash
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/AZURE_DEPLOYMENT/01_INFRASTRUCTURE/terraform

terraform destroy
# Removes all Azure resources
# Press 'yes' to confirm
```

### Remove Resource Group
```bash
az group delete \
  --name safaricom-cc-production-rg \
  --yes --no-wait
```

### Remove State Storage (Optional)
```bash
az storage account delete \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group cosmic \
  --yes
```

---

## 📋 TROUBLESHOOTING

### Issue: Authentication Failed
```bash
# Re-login
az logout
az login

# Check current account
az account show
```

### Issue: AKS Nodes Not Ready
```bash
# Check node status
kubectl describe nodes

# Check resource group limits
az vm list-usage --location eastus

# May need to request limit increase
```

### Issue: Database Connection Timeout
```bash
# Verify PostgreSQL is running
az postgres flexible-server show \
  --name "safaricom-cc-production-postgres" \
  --resource-group "safaricom-cc-production-rg"

# Check firewall rules
az postgres flexible-server firewall-rule list \
  --name "safaricom-cc-production-postgres" \
  --resource-group "safaricom-cc-production-rg"
```

### Issue: Helm Deployment Failed
```bash
# Check pod logs
kubectl logs -n safaricom-cc <pod-name>

# Check events
kubectl describe pod <pod-name> -n safaricom-cc

# Check helm status
helm status safaricom-cc -n safaricom-cc
```

---

## ✅ SUCCESS CHECKLIST

After deployment, verify:

- [ ] Azure account created and logged in
- [ ] Terraform initialized and validated
- [ ] Infrastructure deployed (AKS, PostgreSQL, etc.)
- [ ] Kubernetes cluster accessible
- [ ] Database schema created
- [ ] All applications deployed with Helm
- [ ] All pods running (kubectl get pods -a)
- [ ] Grafana accessible and showing metrics
- [ ] GitHub repository configured with secrets
- [ ] CI/CD workflows running successfully

---

## 🎓 NEXT STEPS

1. **Monitor System**: Check Grafana dashboards regularly
2. **Practice Deployments**: Make changes and use CI/CD
3. **Scale Applications**: Use `kubectl scale` to test auto-scaling
4. **Simulate Failures**: Test failover and recovery procedures
5. **Optimize Costs**: Review Azure cost reports weekly

---

**Deployment Complete!** 🎉

Your production-grade contact center is now running on Azure with automated CI/CD!
