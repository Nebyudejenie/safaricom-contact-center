################################################################################
# TERRAFORM BACKEND
# Remote state management using Azure Storage
################################################################################

terraform {
  backend "azurerm" {
    resource_group_name  = "cosmic"
    storage_account_name = "ccaf78b24d01"
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
