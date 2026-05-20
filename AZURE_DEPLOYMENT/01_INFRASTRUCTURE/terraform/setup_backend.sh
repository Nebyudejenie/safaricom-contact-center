#!/bin/bash

################################################################################
# SETUP AZURE STORAGE BACKEND FOR TERRAFORM STATE
# Automatically creates storage account and configures backend
################################################################################

set -euo pipefail

echo "🔧 Setting up Azure Storage backend for Terraform state..."

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "✅ Subscription ID: $SUBSCRIPTION_ID"

# Use existing resource group or create new one
RG_NAME="cosmic"
if az group exists --name "$RG_NAME" | grep -q "true"; then
  echo "✅ Using existing resource group: $RG_NAME"
  RG_LOCATION=$(az group show --name "$RG_NAME" --query location -o tsv)
  echo "   Location: $RG_LOCATION"
else
  echo "📦 Creating resource group: $RG_NAME"
  az group create \
    --name "$RG_NAME" \
    --location eastus \
    --output none
  RG_LOCATION="eastus"
fi

# Generate valid storage account name (max 24 chars, lowercase only)
# Format: cc + random 10 chars = 12 chars (well under 24)
STORAGE_ACCOUNT_NAME="cc$(openssl rand -hex 5)"
echo "💾 Storage account name: $STORAGE_ACCOUNT_NAME"

# Create storage account
echo "⏳ Creating storage account..."
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RG_NAME" \
  --sku Standard_LRS \
  --output none

echo "✅ Storage account created"

# Create container
echo "⏳ Creating container..."
az storage container create \
  --name terraform-state \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --output none

echo "✅ Container created"

# Update backend.tf
echo "📝 Updating backend.tf..."
cat > backend.tf << EOF
################################################################################
# TERRAFORM BACKEND
# Remote state management using Azure Storage
################################################################################

terraform {
  backend "azurerm" {
    resource_group_name  = "$RG_NAME"
    storage_account_name = "$STORAGE_ACCOUNT_NAME"
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
EOF

echo "✅ backend.tf updated"

# Initialize Terraform with new backend
echo "⏳ Initializing Terraform with new backend..."
terraform init -reconfigure -upgrade

echo ""
echo "═════════════════════════════════════════════════════"
echo "✅ BACKEND SETUP COMPLETE!"
echo "═════════════════════════════════════════════════════"
echo ""
echo "📊 Backend Configuration:"
echo "   Resource Group:     $RG_NAME"
echo "   Storage Account:    $STORAGE_ACCOUNT_NAME"
echo "   Container:          terraform-state"
echo "   Key:                production.tfstate"
echo ""
echo "✅ Terraform state will now be stored in Azure Storage"
echo "✅ Ready to deploy infrastructure with: terraform apply"
echo ""
