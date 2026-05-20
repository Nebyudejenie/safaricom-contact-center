################################################################################
# VARIABLES
# ============================================================================

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "project_name" {
  type        = string
  default     = "safaricom-cc"
  description = "Project name"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Environment (dev, staging, production)"
}

variable "azure_region" {
  type        = string
  default     = "eastus"
  description = "Azure region for deployment"
}

# ============================================================================
# NETWORKING
# ============================================================================

variable "vnet_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Virtual Network CIDR"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "Public subnet CIDR (Application Gateway)"
}

variable "private_subnet_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "Private subnet CIDR (AKS nodes)"
}

variable "database_subnet_cidr" {
  type        = string
  default     = "10.0.3.0/24"
  description = "Database subnet CIDR (PostgreSQL)"
}

# ============================================================================
# DATABASE
# ============================================================================

variable "db_admin_username" {
  type        = string
  default     = "psqladmin"
  description = "PostgreSQL admin username"
  sensitive   = true
}

variable "db_name" {
  type        = string
  default     = "safaricom_cc"
  description = "PostgreSQL database name"
}

variable "db_sku_name" {
  type        = string
  default     = "B_Standard_B2s"
  description = "PostgreSQL SKU (B_Standard_B2s for Burstable, GP_Standard_D2s_v3 for GeneralPurpose)"
}

variable "db_storage_mb" {
  type        = number
  default     = 32768
  description = "PostgreSQL storage in MB (32GB for free tier)"
}

# ============================================================================
# KUBERNETES (AKS)
# ============================================================================

variable "k8s_version" {
  type        = string
  default     = "1.27"
  description = "Kubernetes version"
}

variable "aks_node_count" {
  type        = number
  default     = 3
  description = "Initial number of AKS nodes"
}

variable "aks_min_count" {
  type        = number
  default     = 3
  description = "Minimum number of AKS nodes"
}

variable "aks_max_count" {
  type        = number
  default     = 10
  description = "Maximum number of AKS nodes"
}

variable "aks_vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "AKS node VM size (Standard_B2s for free tier)"
}

# ============================================================================
# TAGS
# ============================================================================

variable "common_tags" {
  type = map(string)
  default = {
    Environment = "production"
    Project     = "SafaricomCC"
    ManagedBy   = "Terraform"
    CreatedDate = "2026-05-20"
  }
  description = "Common tags for all resources"
}
