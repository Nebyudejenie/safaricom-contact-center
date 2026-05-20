################################################################################
# TERRAFORM BACKEND
# Remote state management using Azure Storage
################################################################################

terraform {
  backend "azurerm" {
    resource_group_name  = "cosmic"
    storage_account_name = "ccc0c3f78ed9"
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
