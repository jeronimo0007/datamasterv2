output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.datalake.name
}

output "datalake_containers" {
  value = ["bronze", "silver", "gold", "raw", "processed", "curated"]
}

output "event_hub_namespace" {
  value = azurerm_eventhub_namespace.main.name
}

output "event_hub_name" {
  value = azurerm_eventhub.transactions.name
}

output "event_hub_connection_string" {
  value     = azurerm_eventhub_authorization_rule.send_listen.primary_connection_string
  sensitive = true
}

output "cosmos_db_endpoint" {
  value = azurerm_cosmosdb_account.main.endpoint
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "postgresql_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "application_insights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}

output "container_registry_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "container_app_api_fqdn" {
  value = try(azurerm_container_app.api.latest_revision_fqdn, "")
}

output "container_app_api_name" {
  value = azurerm_container_app.api.name
}

output "enable_analytics_stack" {
  value = var.enable_analytics_stack
}

output "databricks_workspace_url" {
  value = var.enable_analytics_stack ? azurerm_databricks_workspace.main[0].workspace_url : null
}

output "synapse_workspace_name" {
  value = var.enable_analytics_stack ? azurerm_synapse_workspace.main[0].name : null
}

output "machine_learning_workspace_id" {
  value = var.enable_analytics_stack ? azurerm_machine_learning_workspace.main[0].id : null
}
