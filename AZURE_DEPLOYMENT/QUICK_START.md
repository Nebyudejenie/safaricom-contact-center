# 🚀 AZURE DEPLOYMENT - QUICK START

**Time Required:** 45 minutes  
**Complexity:** Advanced  
**Status:** Production-Ready

---

## 5-MINUTE SETUP

### 1. Prerequisites (5 min)
```bash
# Login to Azure
az login

# Verify tools
az --version
terraform --version
kubectl version --client
helm version

# Get subscription ID
az account show --query id -o tsv
```

### 2. Update Configuration (2 min)
```bash
cd AZURE_DEPLOYMENT/01_INFRASTRUCTURE/terraform

# Edit terraform.tfvars
nano terraform.tfvars

# Change:
subscription_id = "YOUR_SUBSCRIPTION_ID"  # From above
azure_region = "eastus"
environment = "production"
```

### 3. Deploy (30 min)
```bash
# Make script executable
chmod +x ../../12_DEPLOYMENT_SCRIPTS/full_deploy.sh

# Deploy everything
../../12_DEPLOYMENT_SCRIPTS/full_deploy.sh production eastus

# ☕ Wait 30 minutes...
```

### 4. Verify (3 min)
```bash
# Check all services running
kubectl get pods -A

# Get Grafana password
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Access dashboard
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open http://localhost:3000
```

**Done!** ✅ Your production system is running on Azure

---

## WHAT YOU GET

```
✅ Azure Virtual Network (VNet)
✅ Azure Kubernetes Service (AKS) - 3 nodes
✅ Azure Database for PostgreSQL (Multi-AZ)
✅ Azure Container Registry (ACR)
✅ Azure Key Vault (secrets)
✅ Azure Monitor + Application Insights
✅ Prometheus + Grafana monitoring
✅ Complete CI/CD with GitHub Actions
✅ Production-grade security & networking
✅ Automatic backups & disaster recovery
```

---

## GITHUB ACTIONS CI/CD

### Setup (2 min)
```bash
# Push to GitHub
git add .
git commit -m "Azure deployment"
git push origin main

# GitHub Actions workflows auto-start
```

### Workflows Included
- ✅ Terraform Plan (on PR)
- ✅ Terraform Apply (on merge)
- ✅ Helm Deploy (automatically)
- ✅ Tests (unit, integration, security)

---

## COST ESTIMATE

| Component | Cost | Notes |
|-----------|------|-------|
| AKS (2 nodes) | $76 | Standard_B2s |
| PostgreSQL | $15 | B_Standard_B1s |
| Container Registry | $5 | Basic tier |
| Networking | $3 | Public IP |
| **Monthly** | **~$100** | Within free tier |

---

## QUICK COMMANDS

```bash
# Access Kubernetes
kubectl get all -A

# View logs
kubectl logs -f -n safaricom-cc deployment/safaricom-cc

# Scale applications
kubectl scale deployment safaricom-cc -n safaricom-cc --replicas=5

# Check database
psql -h <postgres-fqdn> -U psqladmin -d safaricom_cc -c "SELECT COUNT(*) FROM customers;"

# Monitor costs
az costmanagement query --subscription <YOUR_ID> --timeframe MonthToDate

# Destroy (when done)
cd 01_INFRASTRUCTURE/terraform
terraform destroy
```

---

## FULL DOCUMENTATION

1. **Setup**: `09_DOCUMENTATION/SETUP_AZURE.md` (Step-by-step guide)
2. **Architecture**: `00_PLANNING/architecture.md` (Design decisions)
3. **Free Tier**: `00_PLANNING/free_tier_strategy.md` (Cost optimization)
4. **Operations**: `09_DOCUMENTATION/OPERATIONS.md` (Day-to-day)
5. **Troubleshooting**: `09_DOCUMENTATION/TROUBLESHOOTING.md` (Common issues)

---

## NEXT STEPS

### Immediately (0-5 min)
- [ ] Deploy system (follow above)
- [ ] Verify all pods running
- [ ] Access Grafana dashboard

### Within 30 minutes
- [ ] Read SETUP_AZURE.md completely
- [ ] Understand Terraform configuration
- [ ] Check CI/CD pipelines on GitHub

### Within 2 hours
- [ ] Simulate call traffic
- [ ] Monitor system metrics
- [ ] Create custom Grafana dashboard
- [ ] Practice scaling operations

### Extended
- [ ] Deploy updates via CI/CD
- [ ] Test failover scenarios
- [ ] Implement auto-scaling policies
- [ ] Run load tests
- [ ] Practice disaster recovery

---

## FEATURES FOR INTERVIEW

This deployment demonstrates:

✅ **Azure Cloud Architecture**
- VNet with subnets and NSGs
- AKS cluster management
- PostgreSQL database design
- Multi-tier security groups

✅ **Infrastructure as Code**
- Terraform configuration
- Best practices
- State management
- Scalability

✅ **Kubernetes Expertise**
- Cluster setup and configuration
- Namespace management
- RBAC and network policies
- Service discovery and load balancing

✅ **CI/CD Pipeline**
- GitHub Actions workflows
- Terraform automation
- Helm deployments
- Testing and validation

✅ **DevOps Best Practices**
- Monitoring and observability
- Disaster recovery planning
- Security hardening
- Cost optimization

---

## TROUBLESHOOTING

### AKS not ready
```bash
# Check nodes
kubectl get nodes
# If NotReady, wait 5-10 minutes for provisioning
```

### PostgreSQL connection failed
```bash
# Check status
az postgres flexible-server show \
  --name safaricom-cc-production-postgres \
  --resource-group safaricom-cc-production-rg
```

### Helm deployment failed
```bash
# Check events
kubectl describe pod <pod-name> -n safaricom-cc
kubectl logs <pod-name> -n safaricom-cc
```

### GitHub Actions not working
```bash
# Verify secrets
GitHub Repo → Settings → Secrets and variables → Actions
# Should have:
- AZURE_CLIENT_ID
- AZURE_CLIENT_SECRET
- AZURE_SUBSCRIPTION_ID
- AZURE_TENANT_ID
```

---

## SUCCESS CHECKLIST

- [ ] Azure account created
- [ ] Prerequisites installed
- [ ] terraform.tfvars updated
- [ ] `full_deploy.sh` completed
- [ ] All pods running (`kubectl get pods -a`)
- [ ] Grafana accessible (localhost:3000)
- [ ] Database schema created
- [ ] GitHub repository setup
- [ ] CI/CD pipelines running
- [ ] Cost monitoring enabled

---

## YOU'RE READY! 🎉

You now have:
- **Production-grade contact center on Azure**
- **Complete CI/CD automation**
- **Enterprise-level monitoring**
- **Interview-ready demonstration**

---

**Need detailed help?** → Read `09_DOCUMENTATION/SETUP_AZURE.md`

**Ready to deploy?** → Run `./12_DEPLOYMENT_SCRIPTS/full_deploy.sh production eastus`
