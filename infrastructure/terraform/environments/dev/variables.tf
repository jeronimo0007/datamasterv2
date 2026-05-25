variable "resource_group_name" {
  description = "Nome do Resource Group"
  type        = string
  default     = "rg-fraud-detection-dev"
}

variable "location" {
  description = "Região do Azure"
  type        = string
  default     = "brazilsouth"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "fraud-detection"
}

variable "key_vault_name" {
  description = "Nome do Key Vault (3-24 caracteres, único globalmente na Azure). Se null, gera automaticamente (recomendado)."
  type        = string
  default     = null

  validation {
    condition     = var.key_vault_name == null || can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "key_vault_name deve ter 3-24 caracteres, começar com letra e usar apenas letras, números e hífens."
  }
}

variable "storage_account_name" {
  description = "Nome da Storage Account (deve ser único globalmente)"
  type        = string
  default     = "fraudstoragedev"
}

variable "event_hub_namespace" {
  description = "Namespace do Event Hub"
  type        = string
  default     = "fraud-events-dev"
}

variable "db_admin_username" {
  description = "Usuário administrador do banco de dados"
  type        = string
  default     = "fraudadmin"
  sensitive   = true
}

variable "db_admin_password" {
  description = "Senha do administrador do banco de dados"
  type        = string
  sensitive   = true
}

variable "enable_analytics_stack" {
  description = "Se true, cria Synapse, Databricks, Application Insights e Azure ML (custo alto). false = modo econômico."
  type        = bool
  default     = false
}

variable "analytics_high_cost_acknowledged" {
  description = "Obrigatório true se enable_analytics_stack = true (confirma que você aceita o custo). Não substitui orçamento no portal."
  type        = bool
  default     = false
}

variable "synapse_sql_admin_login" {
  description = "Login do administrador SQL do Synapse Workspace"
  type        = string
  default     = "sqladmin"
}

variable "databricks_sku" {
  description = "SKU do Databricks: standard (mais barato para demo) ou premium"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium", "trial"], lower(var.databricks_sku))
    error_message = "databricks_sku deve ser standard, premium ou trial."
  }
}

