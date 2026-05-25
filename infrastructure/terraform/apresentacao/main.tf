terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.67"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  suffix = random_id.suffix.hex
  alnum  = replace(var.project_name, "-", "")

  storage_account_name = coalesce(
    var.storage_account_name,
    substr("${local.alnum}st${local.suffix}", 0, 24)
  )
  event_hub_namespace = coalesce(var.event_hub_namespace, "${var.project_name}-eh-${local.suffix}")
  key_vault_name = coalesce(
    var.key_vault_name,
    substr("${local.alnum}kv${local.suffix}", 0, 24)
  )
  acr_name = substr("${local.alnum}acr${local.suffix}", 0, 50)
  api_image = coalesce(
    var.api_container_image,
    "mcr.microsoft.com/k8se/quickstart:latest"
  )
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name}-${local.suffix}"
  location = var.location
  tags = {
    Environment = "apresentacao"
    Project     = "fraud-detection"
  }
}

# --- Data Lake Gen2 (Medallion: bronze / silver / gold) ---
resource "azurerm_storage_account" "datalake" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  name               = "bronze"
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "silver" {
  name               = "silver"
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "gold" {
  name               = "gold"
  storage_account_id = azurerm_storage_account.datalake.id
}

# Legado (compatível com scripts antigos raw/processed/curated)
resource "azurerm_storage_data_lake_gen2_filesystem" "raw" {
  name               = "raw"
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "processed" {
  name               = "processed"
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "curated" {
  name               = "curated"
  storage_account_id = azurerm_storage_account.datalake.id
}

# --- Event Hubs (streaming) ---
resource "azurerm_eventhub_namespace" "main" {
  name                = local.event_hub_namespace
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  capacity            = 1

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_eventhub" "transactions" {
  name                = "transactions"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = azurerm_resource_group.main.name
  partition_count     = 4
  message_retention   = 1
}

resource "azurerm_eventhub_authorization_rule" "send_listen" {
  name                = "app-policy"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = azurerm_resource_group.main.name
  eventhub_name       = azurerm_eventhub.transactions.name
  listen              = true
  send                = true
  manage              = false
}

# --- Cosmos DB ---
resource "azurerm_cosmosdb_account" "main" {
  name                = substr("${local.alnum}cosmos${local.suffix}", 0, 44)
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "fraud-detection"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_sql_container" "transactions" {
  name                  = "transactions"
  resource_group_name   = azurerm_resource_group.main.name
  account_name          = azurerm_cosmosdb_account.main.name
  database_name         = azurerm_cosmosdb_sql_database.main.name
  partition_key_path    = "/id"
  partition_key_version = 1
  throughput            = 400
}

# --- Key Vault ---
resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  tags = azurerm_resource_group.main.tags
}

# --- PostgreSQL ---
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = substr("${local.alnum}pg${local.suffix}", 0, 63)
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "14"
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password
  sku_name               = "B_Standard_B1ms"
  storage_mb             = 32768

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "fraud_detection"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# --- Observabilidade (sempre — par do slide Monitor / App Insights) ---
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-logs-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_application_insights" "main" {
  name                = "${var.project_name}-appi-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = azurerm_resource_group.main.tags
}

# --- Container Apps + ACR (API Java — mesmo papel do slide) ---
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-cae-${local.suffix}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_container_app" "api" {
  name                         = "${var.project_name}-api-${local.suffix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  secret {
    name  = "registry-password"
    value = azurerm_container_registry.main.admin_password
  }

  secret {
    name  = "eventhub-conn"
    value = azurerm_eventhub_authorization_rule.send_listen.primary_connection_string
  }

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "registry-password"
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "api"
      image  = local.api_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "local"
      }
      env {
        name        = "EVENTHUB_CONNECTION_STRING"
        secret_name = "eventhub-conn"
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.main.connection_string
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = azurerm_resource_group.main.tags

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}
