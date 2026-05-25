variable "resource_group_name" {
  type    = string
  default = "rg-fraud-apresentacao"
}

variable "location" {
  type    = string
  default = "brazilsouth"
}

variable "project_name" {
  type    = string
  default = "fraud-apresentacao"
}

variable "storage_account_name" {
  type        = string
  description = "Único globalmente na Azure (3-24 chars, só minúsculas e números)"
  default     = null
}

variable "event_hub_namespace" {
  type    = string
  default = null
}

variable "key_vault_name" {
  type    = string
  default = null
}

variable "db_admin_username" {
  type      = string
  default   = "fraudadmin"
  sensitive = true
}

variable "db_admin_password" {
  type      = string
  sensitive = true
}

variable "enable_analytics_stack" {
  description = "Databricks + Synapse + Azure ML (custo alto). false = stack alinhada à demo sem DBW/Synapse."
  type        = bool
  default     = false
}

variable "analytics_high_cost_acknowledged" {
  type    = bool
  default = false
}

variable "synapse_sql_admin_login" {
  type    = string
  default = "sqladmin"
}

variable "databricks_sku" {
  type    = string
  default = "standard"
}

variable "api_container_image" {
  description = "Imagem da API Java no ACR (após docker push). null = quickstart até primeiro deploy."
  type        = string
  default     = null
}
