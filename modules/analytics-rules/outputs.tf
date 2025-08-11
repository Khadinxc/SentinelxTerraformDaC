# Outputs for the scheduled analytics rules module
output "rule_details" {
  description = "Details of created scheduled analytics rules"
  value = {
    for key, rule in azurerm_sentinel_alert_rule_scheduled.rules : key => {
      id           = rule.id
      name         = rule.name
      display_name = rule.display_name
      severity     = rule.severity
      enabled      = rule.enabled
      tactics      = rule.tactics
      techniques   = rule.techniques
    }
  }
}

output "rule_ids" {
  description = "Map of rule keys to their Azure resource IDs"
  value = {
    for key, rule in azurerm_sentinel_alert_rule_scheduled.rules : key => rule.id
  }
}

output "rule_names" {
  description = "Map of rule keys to their display names"
  value = {
    for key, rule in azurerm_sentinel_alert_rule_scheduled.rules : key => rule.display_name
  }
}

output "enabled_rules_count" {
  description = "Number of enabled rules"
  value = length([
    for rule in azurerm_sentinel_alert_rule_scheduled.rules : rule.id
    if rule.enabled
  ])
}

output "disabled_rules_count" {
  description = "Number of disabled rules"
  value = length([
    for rule in azurerm_sentinel_alert_rule_scheduled.rules : rule.id
    if !rule.enabled
  ])
}
