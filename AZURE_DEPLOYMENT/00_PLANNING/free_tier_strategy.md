# AZURE FREE TIER STRATEGY

**Goal:** Build production-grade contact center system while staying within Azure free tier limits

---

## 💰 FREE TIER LIMITS & COSTS

### Azure Kubernetes Service (AKS)
- **Free**: AKS cluster control plane is FREE
- **Pay For**: Compute (VM nodes), storage, networking
- **Free Tier Eligible**: Yes (you pay only for nodes)
- **Recommended Nodes**: 2-3 x Standard_B2s = ~$50/month

### Azure Database for PostgreSQL (Flexible Server)
- **Free Tier**: 
  - 1 month completely free
  - Then B_Standard_B1s: ~$15/month
  - 32GB storage included
- **Recommended**: B_Standard_B1s
- **Backups**: 30-day retention included

### Azure Container Registry (ACR)
- **Free Tier**: Basic tier = ~$5/month
- **Includes**: 10GB storage, webhook support
- **Usage**: Store Docker images

### Azure Monitor / Application Insights
- **Free Tier**: 
  - Metrics: 10GB/month free
  - Logs: 5GB/month free
  - Most enterprise features included
- **Cost**: Minimal

### Networking
- **Public IPs**: 1 = ~$3/month
- **Data Transfer**: First 5GB/month free
- **VPN/Express Route**: Not needed for this

### Key Vault
- **Cost**: ~$0.03 per 10,000 transactions
- **Estimated**: <$1/month for this setup

---

## 📊 ESTIMATED TOTAL MONTHLY COST

| Service | Unit Cost | Quantity | Monthly Cost |
|---------|-----------|----------|-------------|
| AKS Nodes (B2s) | $0.052/hour | 2 | ~$76 |
| PostgreSQL (B1s) | $0.50/day | 1 | ~$15 |
| Public IP | $3/month | 1 | $3 |
| ACR Basic | $5/month | 1 | $5 |
| Application Gateway | $0.25/hour | 1 | ~$180 |
| Key Vault | Variable | - | <$1 |
| **TOTAL** | | | **~$280** |

### Cost Optimization Tips
```
1. Use Standard_B2s VMs (cheapest per vCPU)
2. Set auto-scale max to 5 nodes (prevents surprises)
3. Delete resources when not in use
4. Monitor costs daily in Azure Portal
5. Use Application Gateway only if needed (expensive!)
```

---

## 🎯 RECOMMENDED CONFIGURATION FOR FREE TIER

### Terraform Variables to Use
```hcl
# terraform.tfvars - Optimized for free tier

# Use cheapest VM size
aks_vm_size = "Standard_B2s"    # 2 vCPU, 4GB RAM = cheapest

# Use smallest database
db_sku_name = "B_Standard_B1s"  # 1 vCPU, 2GB RAM

# Use minimal nodes
aks_node_count = 2              # Start small
aks_min_count  = 2              # Never go below 2
aks_max_count  = 5              # Limit auto-scale

# Use smallest storage
db_storage_mb = 32768           # 32GB (included)

# Disable expensive features
# Application Gateway = remove or use simple LB
```

---

## 📈 SCALING STRATEGY

### Phase 1: Development (Months 1-2)
```
Configuration:
- 2 AKS nodes (Standard_B2s)
- PostgreSQL B1s
- No Application Gateway (use Ingress instead)

Estimated Cost: ~$95/month
Estimated $200 free credits: LASTS 2+ MONTHS
```

### Phase 2: Testing (Months 2-3)
```
Configuration:
- 3 AKS nodes (scale up for load testing)
- PostgreSQL B2s (if needed for performance)
- Add Application Gateway if required

Estimated Cost: ~$180/month
```

### Phase 3: Production (After Credits)
```
Configuration:
- 3-5 AKS nodes (Standard_D2s_v3) - better performance
- PostgreSQL Premium tier
- Full monitoring and backup
- Application Gateway with WAF

Estimated Cost: ~$800+/month
```

---

## ⚠️ COST TRAPS TO AVOID

### 1. Application Gateway
```
Problem: $0.25/hour = ~$180/month
Solution: Use Ingress-nginx instead (free)

# Skip in terraform.tf:
# Remove Application Gateway resource
# Add Ingress Nginx Helm chart
```

### 2. Data Transfer
```
Problem: Egress costs $0.05/GB
Solution: Keep data within region

# Recommendation:
- All services in same region (eastus)
- Use private endpoints where possible
```

### 3. Storage Snapshots
```
Problem: Snapshots cost ~$0.10 per GB-month
Solution: Use managed backup only

# Recommendation:
- Rely on built-in PostgreSQL backups
- Create snapshots only when necessary
```

### 4. Multiple Clusters
```
Problem: Each cluster = separate costs
Solution: Use one cluster for all environments

# Recommendation:
- One cluster with namespaces
- dev, staging, production namespaces
- Not separate clusters
```

### 5. Unused Resources
```
Problem: Forgot to delete something = surprise bill
Solution: Monitor Azure Portal daily

# Daily:
az costmanagement query \
  --subscription YOUR_ID \
  --timeframe MonthToDate
```

---

## 🔍 MONITORING FREE TIER USAGE

### Daily Cost Check
```bash
# Azure Portal
# Home → Cost Management + Billing → Cost Analysis

# Command line
az costmanagement query \
  --subscription "YOUR_SUBSCRIPTION_ID" \
  --timeframe MonthToDate \
  --granularity Daily \
  --metrics actualCost

# View by resource
az resource list --resource-group safaricom-cc-production-rg \
  --query "[].{Name:name, Type:type}"
```

### Alerts for Overspending
```bash
# Azure Portal
# Alerts → Create budget alert
# Set budget: $200
# Alert at: 80%, 100%
```

### Resource Tagging for Tracking
```hcl
# terraform.tfvars
common_tags = {
  Environment = "production"
  Project     = "SafaricomCC"
  CostCenter  = "Engineering"
  Owner       = "DevOps"
  CreatedDate = "2026-05-20"
}

# Filter costs by tags in Cost Management
```

---

## 🔄 SWITCHING FROM FREE TIER TO PAID

### When to Upgrade
- After 12 months (free tier expires)
- Need more performance than B2s
- Running production with SLA requirements
- Need 99.99% uptime guarantee

### Migration Path
```
1. Keep Terraform code (already scalable)
2. Update terraform.tfvars:
   - Change VM size to D2s_v3
   - Change DB to Premium tier
   - Add Application Gateway
   - Add replicas for HA

3. Plan and apply:
   terraform plan
   terraform apply

4. No downtime (Kubernetes handles it)
```

---

## ✅ RECOMMENDATIONS

### For Interview Preparation
```
Strategy: Use free tier to learn
- Deploy full production system
- Practice DevOps concepts
- Show understanding of cloud architecture
- Demonstrate cost optimization awareness

Duration: 2-3 months
Cost: Minimal ($95-180/month)
```

### For Production Use
```
Strategy: Monitor costs carefully
- Set up Azure Cost Management alerts
- Review costs weekly
- Right-size resources based on usage
- Consider reserved instances after 12 months

Estimated: $300-500/month for this setup
```

---

## 📚 AZURE FREE TIER RESOURCES

- https://azure.microsoft.com/en-us/free/
- https://learn.microsoft.com/en-us/azure/cost-management-billing/
- https://azure.microsoft.com/en-us/pricing/details/kubernetes-service/
- https://azure.microsoft.com/en-us/pricing/details/postgresql/

---

## 💡 FINAL RECOMMENDATION

**Use this configuration for Azure Free Tier:**

```hcl
# terraform.tfvars

subscription_id = "YOUR_ID"
environment = "production"
azure_region = "eastus"  # Consistent region

# Networking
vnet_cidr = "10.0.0.0/16"

# Database - B1s = cheapest
db_sku_name = "B_Standard_B1s"
db_storage_mb = 32768

# AKS - B2s is sweet spot
aks_vm_size = "Standard_B2s"
aks_node_count = 2
aks_min_count = 2
aks_max_count = 5

# Skip expensive features
# Remove: Application Gateway
# Use: Ingress + Kubernetes Service
```

**Expected Result:**
- Full production system running
- ~$95/month cost (within free tier credits for months 1-2)
- Scalable to production configuration
- Perfect for interview demonstration

---

**Ready to deploy? Follow: SETUP_AZURE.md**
