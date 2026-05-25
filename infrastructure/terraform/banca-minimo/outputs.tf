output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "acr_name" {
  value       = azurerm_container_registry.acr.name
  description = "Use com: az acr login --name <este_valor>"
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "container_app_name" {
  value = azurerm_container_app.api.name
}

output "container_app_fqdn" {
  value       = try(azurerm_container_app.api.latest_revision_fqdn, "")
  description = "Teste health após deploy da API em /health na porta 8000"
}
