output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.datalake.name
}

output "event_hub_namespace" {
  value = azurerm_eventhub_namespace.main.name
}

output "event_hub_name" {
  value = azurerm_eventhub.transactions.name
}

output "cosmos_db_endpoint" {
  value = azurerm_cosmosdb_account.main.endpoint
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "postgresql_server_name" {
  value = azurerm_postgresql_flexible_server.main.name
}

output "enable_analytics_stack" {
  value       = var.enable_analytics_stack
  description = "Se false, Synapse/Databricks/ML não foram provisionados (economia)."
}

output "synapse_workspace_name" {
  value = var.enable_analytics_stack ? azurerm_synapse_workspace.main[0].name : null
}

output "synapse_sql_admin_login" {
  value = var.enable_analytics_stack ? var.synapse_sql_admin_login : null
}

output "databricks_workspace_url" {
  value = var.enable_analytics_stack ? azurerm_databricks_workspace.main[0].workspace_url : null
}

output "machine_learning_workspace_id" {
  value = var.enable_analytics_stack ? azurerm_machine_learning_workspace.main[0].id : null
}

output "application_insights_connection_string" {
  value     = var.enable_analytics_stack ? azurerm_application_insights.main[0].connection_string : null
  sensitive = true
}

