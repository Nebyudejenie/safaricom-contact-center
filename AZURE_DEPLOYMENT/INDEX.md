# AZURE DEPLOYMENT - NAVIGATION GUIDE

**Complete navigation and quick reference for Azure contact center deployment**

---

## 🚀 START HERE

### 5-Minute Quick Start
- **Read**: [QUICK_START.md](QUICK_START.md)
- **Time**: 5 minutes
- **Goal**: Understand what you'll deploy

### 30-Minute Setup
- **Read**: [09_DOCUMENTATION/SETUP_AZURE.md](09_DOCUMENTATION/SETUP_AZURE.md)
- **Time**: 30 minutes
- **Goal**: Step-by-step Azure deployment

### 1-Hour Complete Guide
- **Read**: [09_DOCUMENTATION/DEPLOYMENT.md](09_DOCUMENTATION/DEPLOYMENT.md)
- **Time**: 60 minutes
- **Goal**: Full deployment with explanations

---

## 📚 DOCUMENTATION

### Planning & Strategy
| Document | Purpose | Read When |
|----------|---------|-----------|
| [00_PLANNING/free_tier_strategy.md](00_PLANNING/free_tier_strategy.md) | Optimize costs for free tier | Before deployment |
| [00_PLANNING/architecture.md](00_PLANNING/architecture.md) | Understand system design | Understanding design |
| [00_PLANNING/cost_analysis.md](00_PLANNING/cost_analysis.md) | Budget breakdown | Planning budget |

### Infrastructure
| Document | Purpose | Read When |
|----------|---------|-----------|
| [01_INFRASTRUCTURE/terraform/main.tf](01_INFRASTRUCTURE/terraform/main.tf) | Terraform code | Understanding code |
| [01_INFRASTRUCTURE/terraform/variables.tf](01_INFRASTRUCTURE/terraform/variables.tf) | Variable definitions | Customizing deployment |
| [01_INFRASTRUCTURE/terraform/terraform.tfvars](01_INFRASTRUCTURE/terraform/terraform.tfvars) | Configuration values | Before `terraform apply` |

### Deployment Scripts
| Script | Purpose | Use When |
|--------|---------|----------|
| [12_DEPLOYMENT_SCRIPTS/full_deploy.sh](12_DEPLOYMENT_SCRIPTS/full_deploy.sh) | Complete deployment automation | Ready to deploy |

### Operations & Troubleshooting
| Document | Purpose | Read When |
|----------|---------|-----------|
| [09_DOCUMENTATION/OPERATIONS.md](09_DOCUMENTATION/OPERATIONS.md) | Day-to-day operations | Running the system |
| [09_DOCUMENTATION/TROUBLESHOOTING.md](09_DOCUMENTATION/TROUBLESHOOTING.md) | Common issues & solutions | Something breaks |

### CI/CD
| File | Purpose | Use When |
|------|---------|----------|
| [07_CI_CD/.github/workflows/terraform-plan.yml](07_CI_CD/.github/workflows/terraform-plan.yml) | Plan infrastructure changes | PR validation |
| [07_CI_CD/.github/workflows/terraform-apply.yml](07_CI_CD/.github/workflows/terraform-apply.yml) | Deploy infrastructure | Merge to main |
| [07_CI_CD/.github/workflows/helm-deploy.yml](07_CI_CD/.github/workflows/helm-deploy.yml) | Deploy applications | Application updates |
| [07_CI_CD/.github/workflows/test.yml](07_CI_CD/.github/workflows/test.yml) | Run tests | Test automation |

---

## 🎯 QUICK REFERENCE

### Key Commands

#### Azure CLI
```bash
# Login
az login

# Get subscription
az account show --query id

# Check resources
az group list --output table
az aks list --output table
az postgres flexible-server list --output table
```

#### Terraform
```bash
# Initialize
terraform init

# Validate
terraform validate

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Destroy
terraform destroy
```

#### Kubernetes
```bash
# Get credentials
az aks get-credentials --resource-group <rg> --name <cluster>

# Check status
kubectl get nodes
kubectl get pods -a
kubectl get svc -a

# Logs
kubectl logs <pod> -n <namespace>

# Scale
kubectl scale deployment <name> --replicas=5
```

#### Helm
```bash
# Add repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts

# Deploy
helm upgrade --install <name> <chart> --namespace <ns>

# Status
helm list -n <namespace>
helm status <release> -n <namespace>
```

---

## 📊 FOLDER STRUCTURE

```
AZURE_DEPLOYMENT/
├── README.md                          ← Overview
├── QUICK_START.md                     ← 5-min start
├── INDEX.md                           ← You are here
│
├── 00_PLANNING/
│   ├── free_tier_strategy.md          ← Cost optimization
│   ├── architecture.md                ← Design decisions
│   ├── cost_analysis.md               ← Budget breakdown
│   └── requirements.md                ← System requirements
│
├── 01_INFRASTRUCTURE/terraform/
│   ├── main.tf                        ← Infrastructure code
│   ├── variables.tf                   ← Variable definitions
│   ├── terraform.tfvars               ← Configuration
│   ├── backend.tf                     ← State management
│   └── outputs.tf                     ← Outputs
│
├── 02_DATABASE/schema/
│   ├── 01_create_tables.sql           ← Database schema
│   ├── 02_create_indexes.sql          ← Indexes
│   └── 03_create_views.sql            ← Database views
│
├── 04_KUBERNETES/
│   ├── helm/                          ← Helm charts
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── values-production.yaml
│   └── manifests/                     ← K8s manifests
│       ├── rbac.yaml
│       └── network-policy.yaml
│
├── 05_MONITORING/
│   ├── prometheus/                    ← Prometheus config
│   │   └── prometheus.yml
│   └── grafana/                       ← Grafana dashboards
│       └── dashboards/
│
├── 07_CI_CD/.github/workflows/
│   ├── terraform-plan.yml             ← Plan workflow
│   ├── terraform-apply.yml            ← Apply workflow
│   ├── helm-deploy.yml                ← Deploy workflow
│   ├── test.yml                       ← Test workflow
│   └── security-scan.yml              ← Security workflow
│
├── 09_DOCUMENTATION/
│   ├── SETUP_AZURE.md                 ← Step-by-step setup
│   ├── DEPLOYMENT.md                  ← Full deployment guide
│   ├── OPERATIONS.md                  ← Operations guide
│   └── TROUBLESHOOTING.md             ← Common issues
│
└── 12_DEPLOYMENT_SCRIPTS/
    ├── full_deploy.sh                 ← Complete deployment
    ├── canary_deploy.sh               ← Canary deployment
    └── rollback.sh                    ← Rollback script
```

---

## 🔄 COMMON WORKFLOWS

### First-Time Deployment
1. Read [QUICK_START.md](QUICK_START.md) - 5 min
2. Review [00_PLANNING/free_tier_strategy.md](00_PLANNING/free_tier_strategy.md) - 10 min
3. Follow [09_DOCUMENTATION/SETUP_AZURE.md](09_DOCUMENTATION/SETUP_AZURE.md) - 30 min
4. Run `./12_DEPLOYMENT_SCRIPTS/full_deploy.sh production eastus` - 30 min
5. Verify with `kubectl get pods -a` - 2 min

### Updating Application
1. Make code changes
2. `git commit` and `git push` to main
3. GitHub Actions automatically:
   - Plans infrastructure changes
   - Tests code
   - Deploys with Helm
4. Monitor: GitHub Actions tab or `kubectl rollout status`

### Scaling System
1. Update [01_INFRASTRUCTURE/terraform/terraform.tfvars](01_INFRASTRUCTURE/terraform/terraform.tfvars)
   - Change `aks_vm_size`, `aks_node_count`, `db_sku_name`
2. Run: `terraform plan` and `terraform apply`
3. Or use CI/CD: `git commit` and `git push`

### Monitoring System
1. Access Grafana: `kubectl port-forward -n monitoring svc/grafana 3000:80`
2. Browse http://localhost:3000
3. Username: admin
4. Password: `kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode`

### Troubleshooting Issues
1. Check [09_DOCUMENTATION/TROUBLESHOOTING.md](09_DOCUMENTATION/TROUBLESHOOTING.md)
2. View pod logs: `kubectl logs <pod> -n <namespace>`
3. Describe resource: `kubectl describe pod <pod> -n <namespace>`
4. Check events: `kubectl get events -n <namespace>`

---

## 🎓 LEARNING PATH

### For Beginners
```
1. QUICK_START.md (5 min) - Overview
2. free_tier_strategy.md (10 min) - Understanding costs
3. SETUP_AZURE.md (30 min) - Hands-on setup
4. Deploy and observe (30 min)
5. Check Grafana dashboard
```

### For Intermediate
```
1. DEPLOYMENT.md (60 min) - Complete understanding
2. Review main.tf (20 min) - Terraform code
3. Check Kubernetes manifests (15 min)
4. Configure CI/CD on GitHub (20 min)
5. Deploy changes via CI/CD
```

### For Advanced
```
1. Architecture.md (30 min) - Design decisions
2. Customize Terraform code
3. Implement advanced patterns
4. Setup auto-scaling policies
5. Practice disaster recovery
```

---

## 💡 TIPS & TRICKS

### Monitor Costs
```bash
# Daily cost check
az costmanagement query \
  --subscription "YOUR_ID" \
  --timeframe MonthToDate
```

### Quick Access to Resources
```bash
# Set environment variables
export RG="safaricom-cc-production-rg"
export AKS="safaricom-cc-production-aks"
export PG="safaricom-cc-production-postgres"

# Reuse in commands
kubectl get nodes  # Already configured
az postgres flexible-server show --name $PG --resource-group $RG
```

### Common Helm Operations
```bash
# List all releases
helm list -a

# Upgrade application
helm upgrade safaricom-cc ./04_KUBERNETES/helm -n safaricom-cc

# Rollback
helm rollback safaricom-cc -n safaricom-cc

# Delete
helm uninstall safaricom-cc -n safaricom-cc
```

---

## ✅ SUCCESS INDICATORS

Your deployment is successful when:

- ✅ All 3 AKS nodes show `Ready` (`kubectl get nodes`)
- ✅ All pods running in all namespaces (`kubectl get pods -a`)
- ✅ Grafana dashboard accessible and showing metrics
- ✅ Database schema created (`psql -c "\dt"`)
- ✅ GitHub Actions workflows running successfully
- ✅ Cost monitoring shows <$100/month

---

## 📞 SUPPORT RESOURCES

### Official Documentation
- Azure: https://learn.microsoft.com/en-us/azure/
- Terraform: https://www.terraform.io/docs
- Kubernetes: https://kubernetes.io/docs/
- Helm: https://helm.sh/docs/
- PostgreSQL: https://www.postgresql.org/docs/

### Azure Specific
- AKS: https://learn.microsoft.com/en-us/azure/aks/
- PostgreSQL: https://learn.microsoft.com/en-us/azure/postgresql/
- Cost Management: https://learn.microsoft.com/en-us/azure/cost-management-billing/

---

## 🚀 YOU'RE READY!

Start with: **[QUICK_START.md](QUICK_START.md)**

Or go straight to setup: **[09_DOCUMENTATION/SETUP_AZURE.md](09_DOCUMENTATION/SETUP_AZURE.md)**

---

**Last Updated**: 2026-05-20  
**Status**: Production-Ready  
**Interview-Ready**: ✅ Yes
