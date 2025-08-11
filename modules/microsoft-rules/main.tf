# Microsoft Security Rules Module
# This module creates Microsoft security incident rules for Sentinel

locals {
  # Process Microsoft rules with defaults
  processed_rules = {
    for rule_key, rule_config in var.microsoft_rules : rule_key => {
      display_name                = rule_config.display_name
      description                = coalesce(rule_config.description, "Managed by SentinelDaC Framework - Microsoft Security Rule")
      enabled                    = coalesce(rule_config.enabled, true)
      alert_rule_template_guid   = rule_config.alert_rule_template_guid
      alert_rule_template_version = coalesce(rule_config.alert_rule_template_version, "1.0.0")
      product_filter             = coalesce(rule_config.product_filter, "Microsoft Cloud App Security")
    }
  }
}

# Create Microsoft security incident rules
resource "azurerm_sentinel_alert_rule_ms_security_incident" "rules" {
  for_each = local.processed_rules

  name                       = each.value.display_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name              = each.value.display_name
  description               = each.value.description
  enabled                   = each.value.enabled
  product_filter            = each.value.product_filter
  severity_filter           = ["High", "Medium", "Low", "Informational"]
  alert_rule_template_guid  = each.value.alert_rule_template_guid

  depends_on = [
    # Ensure Sentinel is onboarded before creating rules
  ]
}
