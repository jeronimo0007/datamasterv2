# main.tf - Azure
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Data Lake Gen2 (Equivalente AWS: S3)
resource "azurerm_storage_account" "data_lake" {
  name                      = "stdlakedata${var.environment}"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "ZRS"
  account_kind              = "StorageV2"
  is_hns_enabled            = true
  
  # Enable soft delete
  blob_properties {
    delete_retention_policy {
      days = 30
    }
  }
  
  tags = {
    Environment = var.environment
    Application = "FraudDetection"
  }
}

# Azure Event Hubs (Equivalente AWS: Kinesis)
resource "azurerm_eventhub_namespace" "events" {
  name                = "evhns-fraud-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Standard"
  capacity            = 2
  
  tags = {
    Environment = var.environment
  }
}

resource "azurerm_eventhub" "transactions" {
  name                = "transactions"
  namespace_name      = azurerm_eventhub_namespace.events.name
  resource_group_name = azurerm_resource_group.main.name
  partition_count     = 4
  message_retention   = 7
}

# Azure Databricks (Equivalente AWS: EMR)
resource "azurerm_databricks_workspace" "databricks" {
  name                = "dbw-fraud-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "premium"
  
  custom_parameters {
    no_public_ip = true
    virtual_network_id = azurerm_virtual_network.main.id
  }
  
  tags = {
    Environment = var.environment
  }
}

# Azure Synapse Analytics (Equivalente AWS: Redshift)
resource "azurerm_synapse_workspace" "synapse" {
  name                                 = "synws-fraud-${var.environment}"
  resource_group_name                  = azurerm_resource_group.main.name
  location                             = var.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.curated.id
  sql_administrator_login              = "sqladmin"
  sql_administrator_login_password     = random_password.sql_password.result
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = {
    Environment = var.environment
  }
}

# Azure Cosmos DB (Equivalente AWS: DynamoDB)
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "cosmos-fraud-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "MongoDB"
  
  capabilities {
    name = "EnableMongo"
  }
  
  consistency_policy {
    consistency_level       = "Session"
  }
  
  geo_location {
    location          = var.location
    failover_priority = 0
  }
  
  tags = {
    Environment = var.environment
  }
}

# Azure Machine Learning (Equivalente AWS: SageMaker)
resource "azurerm_machine_learning_workspace" "ml_workspace" {
  name                    = "mlw-fraud-${var.environment}"
  location                = var.location
  resource_group_name     = azurerm_resource_group.main.name
  application_insights_id = azurerm_application_insights.app_insights.id
  key_vault_id           = azurerm_key_vault.kv.id
  storage_account_id     = azurerm_storage_account.data_lake.id
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = {
    Environment = var.environment
  }
}