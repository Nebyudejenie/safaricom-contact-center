################################################################################
# TERRAFORM VARIABLES
# Azure Contact Center Production Deployment
# ============================================================================

# REQUIRED: Set your Azure subscription ID
# Get it with: az account show --query id -o tsv
subscription_id = "df5f2896-9c0d-4d96-9355-84c9cbc17e30"

# ENVIRONMENT CONFIGURATION
project_name = "safaricom-cc"
environment  = "production"
azure_region = "eastus"

# NETWORKING
vnet_cidr              = "10.0.0.0/16"
public_subnet_cidr     = "10.0.1.0/24"
private_subnet_cidr    = "10.0.2.0/24"
database_subnet_cidr   = "10.0.3.0/24"

# DATABASE
db_admin_username = "psqladmin"
db_name           = "safaricom_cc"

# Azure Free Tier: Use B1ms (cheapest tier)
# For production: Use Standard_D2s_v3 or Standard_E2s_v3
db_sku_name  = "B1ms"
db_storage_mb = 32768  # 32GB

# KUBERNETES (AKS)
k8s_version = "1.27"

# Auto-scaling configuration
# For free tier: Start small, auto-scale as needed
aks_node_count = 2
aks_min_count  = 2
aks_max_count  = 5

# Azure Free Tier: Use Standard_B2s
# For production: Use Standard_D2s_v3 or higher
aks_vm_size = "Standard_B2s"

# TAGS
common_tags = {
  Environment = "production"
  Project     = "SafaricomCC"
  ManagedBy   = "Terraform"
  CreatedDate = "2026-05-20"
  Owner       = "DevOps"
  CostCenter  = "Engineering"
}
