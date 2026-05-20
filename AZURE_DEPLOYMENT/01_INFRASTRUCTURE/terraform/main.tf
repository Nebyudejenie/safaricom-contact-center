################################################################################
# AZURE CONTACT CENTER - PRODUCTION INFRASTRUCTURE
# Terraform configuration for enterprise-grade contact center on Azure
################################################################################

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
  subscription_id = var.subscription_id
}

# ============================================================================
# RESOURCE GROUP
# ============================================================================

resource "azurerm_resource_group" "main" {
  name       = "${var.project_name}-${var.environment}-rg"
  location   = var.azure_region
  tags       = var.common_tags
}

# ============================================================================
# VIRTUAL NETWORK & NETWORKING
# ============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.common_tags
}

# Public Subnet (for NAT Gateway and Application Gateway)
resource "azurerm_subnet" "public" {
  name                 = "${var.project_name}-${var.environment}-public-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.public_subnet_cidr]
}

# Private Subnet (for AKS nodes)
resource "azurerm_subnet" "private" {
  name                 = "${var.project_name}-${var.environment}-private-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_subnet_cidr]
}

# Database Subnet (for PostgreSQL)
resource "azurerm_subnet" "database" {
  name                 = "${var.project_name}-${var.environment}-database-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.database_subnet_cidr]

  service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault"]
}

# ============================================================================
# NETWORK SECURITY GROUPS
# ============================================================================

# NSG for public subnet (Application Gateway)
resource "azurerm_network_security_group" "public" {
  name                = "${var.project_name}-${var.environment}-public-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.common_tags

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSIP"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAll"
    priority                   = 3000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for private subnet (AKS)
resource "azurerm_network_security_group" "private" {
  name                = "${var.project_name}-${var.environment}-private-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.common_tags

  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowPublicSubnet"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.public_subnet_cidr
    destination_address_prefix = var.private_subnet_cidr
  }
}

# NSG for database subnet
resource "azurerm_network_security_group" "database" {
  name                = "${var.project_name}-${var.environment}-database-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.common_tags

  security_rule {
    name                       = "AllowPostgrSQL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.private_subnet_cidr
    destination_address_prefix = var.database_subnet_cidr
  }

  security_rule {
    name                       = "DenyAll"
    priority                   = 3000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.public.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

# ============================================================================
# AZURE CONTAINER REGISTRY
# ============================================================================

resource "azurerm_container_registry" "main" {
  name                = "${replace(var.project_name, "-", "")}${var.environment}acr"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  admin_enabled       = true
  sku                 = "Basic"
  tags                = var.common_tags
}

# ============================================================================
# KEY VAULT FOR SECRETS
# ============================================================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}-${var.environment}-kv"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = var.common_tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]
  }
}

# Database password secret
resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.main.id
}

# ============================================================================
# AZURE DATABASE FOR POSTGRESQL
# ============================================================================

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.project_name}-${var.environment}-postgres"
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  version                = "15"
  administrator_login    = var.db_admin_username
  administrator_password = azurerm_key_vault_secret.db_password.value
  sku_name               = var.db_sku_name
  storage_mb             = var.db_storage_mb
  tags                   = var.common_tags

  delegated_subnet_id             = azurerm_subnet.database.id
  private_dns_zone_id             = azurerm_private_dns_zone.postgres.id
  backup_retention_days           = 30
  geo_redundant_backup_enabled    = false
  auto_grow_enabled               = true
  high_availability {
    mode = "ZoneRedundant"
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres
  ]
}

# PostgreSQL database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name            = var.db_name
  server_id       = azurerm_postgresql_flexible_server.main.id
  collation       = "en_US.utf8"
  charset         = "UTF8"
}

# PostgreSQL firewall rule to allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# PostgreSQL firewall rule for AKS
resource "azurerm_postgresql_flexible_server_firewall_rule" "aks" {
  name             = "AllowAKS"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Private DNS zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

# Link private DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.project_name}-${var.environment}-postgres-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# ============================================================================
# AZURE KUBERNETES SERVICE (AKS)
# ============================================================================

resource "azurerm_user_assigned_identity" "aks" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_name}-${var.environment}-aks-identity"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.common_tags
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-${var.environment}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.k8s_version
  tags                = var.common_tags

  default_node_pool {
    name                = "default"
    node_count          = var.aks_node_count
    vm_size             = var.aks_vm_size
    vnet_subnet_id      = azurerm_subnet.private.id
    enable_auto_scaling = true
    min_count           = var.aks_min_count
    max_count           = var.aks_max_count
    max_pods            = 110
    os_disk_type        = "Managed"
    os_disk_size_gb     = 50
    type                = "VirtualMachineScaleSets"

    tags = var.common_tags
  }

  identity {
    type            = "UserAssigned"
    identity_ids    = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = "10.100.0.0/16"
    dns_service_ip    = "10.100.0.10"
    load_balancer_sku = "Standard"
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.main.id
  }

  addon_profile {
    http_application_routing {
      enabled = false
    }
  }

  depends_on = [
    azurerm_subnet.private,
    azurerm_application_gateway.main
  ]
}

# ============================================================================
# APPLICATION GATEWAY (Load Balancer)
# ============================================================================

resource "azurerm_public_ip" "appgw" {
  name                = "${var.project_name}-${var.environment}-appgw-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.common_tags
}

resource "azurerm_application_gateway" "main" {
  name                = "${var.project_name}-${var.environment}-appgw"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.common_tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.public.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_port {
    name = "https"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name = "backend-pool"
  }

  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "backend-http-settings"
  }
}

# ============================================================================
# KUBERNETES PROVIDER CONFIGURATION
# ============================================================================

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  }
}

# ============================================================================
# KUBERNETES NAMESPACES
# ============================================================================

resource "kubernetes_namespace" "safaricom_cc" {
  metadata {
    name = "safaricom-cc"
    labels = {
      "app.kubernetes.io/name"       = "safaricom-cc"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/name"       = "monitoring"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ============================================================================
# RBAC CONFIGURATION
# ============================================================================

resource "kubernetes_role" "cc_developer" {
  metadata {
    name      = "cc-developer"
    namespace = kubernetes_namespace.safaricom_cc.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/logs"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding" "cc_developer" {
  metadata {
    name      = "cc-developer"
    namespace = kubernetes_namespace.safaricom_cc.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.cc_developer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = kubernetes_namespace.safaricom_cc.metadata[0].name
  }
}

# ============================================================================
# NETWORK POLICIES
# ============================================================================

resource "kubernetes_network_policy" "safaricom_cc" {
  metadata {
    name      = "cc-network-policy"
    namespace = kubernetes_namespace.safaricom_cc.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app" = "safaricom-cc"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            "app" = "safaricom-cc"
          }
        }
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {
            "app" = "safaricom-cc"
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            "name" = "kube-system"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "53"
      }
    }
  }

  depends_on = [kubernetes_namespace.safaricom_cc]
}

# ============================================================================
# MONITORING
# ============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-${var.environment}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.common_tags
}

resource "azurerm_application_insights" "main" {
  name                = "${var.project_name}-${var.environment}-ai"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  tags                = var.common_tags
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.main.name
  description = "AKS cluster name"
}

output "aks_cluster_id" {
  value       = azurerm_kubernetes_cluster.main.id
  description = "AKS cluster ID"
}

output "postgresql_fqdn" {
  value       = azurerm_postgresql_flexible_server.main.fqdn
  description = "PostgreSQL FQDN"
}

output "postgresql_connection_string" {
  value       = "postgresql://${var.db_admin_username}:${random_password.db_password.result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.db_name}"
  sensitive   = true
  description = "PostgreSQL connection string"
}

output "acr_login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "Azure Container Registry login server"
}

output "application_gateway_ip" {
  value       = azurerm_public_ip.appgw.ip_address
  description = "Application Gateway public IP"
}

output "key_vault_id" {
  value       = azurerm_key_vault.main.id
  description = "Key Vault ID"
}

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Resource Group name"
}
