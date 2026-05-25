# Garantias no código: não dá para aplicar Synapse/DBW/ML sem confirmação explícita.
# Na Azure, use orçamentos e alertas (Cost Management) — a nuvem não tem “teto rígido” universal.

check "analytics_requires_cost_acknowledgement" {
  assert {
    condition = (
      !var.enable_analytics_stack || var.analytics_high_cost_acknowledged
    )
    error_message = <<-EOT
      enable_analytics_stack = true gera custo elevado (Synapse, Databricks, Azure ML).
      Defina explicitamente no tfvars: analytics_high_cost_acknowledged = true
      após aceitar o risco. Caso contrário mantenha enable_analytics_stack = false.
    EOT
  }
}
