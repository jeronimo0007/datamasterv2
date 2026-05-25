check "analytics_requires_cost_acknowledgement" {
  assert {
    condition     = !var.enable_analytics_stack || var.analytics_high_cost_acknowledged
    error_message = "enable_analytics_stack = true exige analytics_high_cost_acknowledged = true no tfvars."
  }
}
