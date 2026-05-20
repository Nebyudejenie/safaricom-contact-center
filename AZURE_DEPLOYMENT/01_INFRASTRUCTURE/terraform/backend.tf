################################################################################
# TERRAFORM BACKEND
# Remote state management using Azure Storage
# ============================================================================

# To use remote state, first create the storage account:
#
# az group create --name tfstate --location eastus
# az storage account create --resource-group tfstate \
#   --name safaricomccstate \
#   --sku Standard_LRS
# az storage container create -n terraform-state \
#   --account-name safaricomccstate
#
# Then update the backend configuration below with your storage account details.

terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate"
    storage_account_name = "safaricomccstate"
    container_name       = "terraform-state"
    key                  = "production.tfstate"
  }
}

# For local development, comment out the backend block above and use local state:
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
