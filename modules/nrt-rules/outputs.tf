# Outputs for NRT Rules Module

output "nrt_rules" {
  description = "Map of created NRT alert rules with their IDs and configurations"
  value = {
    for key, rule in azurerm_sentinel_alert_rule_nrt.rules : key => {
      id           = rule.id
      name         = rule.name
      display_name = rule.display_name
      description  = rule.description
      severity     = rule.severity
      enabled      = rule.enabled
    }
  }
}

output "nrt_rules_count" {
  description = "Number of NRT rules created"
  value       = length(azurerm_sentinel_alert_rule_nrt.rules)
}
