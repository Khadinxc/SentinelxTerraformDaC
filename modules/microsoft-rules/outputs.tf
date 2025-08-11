# Outputs for the Microsoft security rules module
output "rule_details" {
  description = "Details of created Microsoft security rules"
  value = {
    for key, rule in azurerm_sentinel_alert_rule_ms_security_incident.rules : key => {
      id                      = rule.id
      name                    = rule.name
      display_name           = rule.display_name
      enabled                = rule.enabled
      product_filter         = rule.product_filter
      severity_filter        = rule.severity_filter
    }
  }
}

output "rule_ids" {
  description = "Map of rule keys to their Azure resource IDs"
  value = {
    for key, rule in azurerm_sentinel_alert_rule_ms_security_incident.rules : key => rule.id
  }
}

output "rule_names" {
  description = "Map of rule keys to their display names"
  value = {
    for key, rule in azurerm_sentinel_alert_rule_ms_security_incident.rules : key => rule.display_name
  }
}

output "enabled_rules_count" {
  description = "Number of enabled Microsoft security rules"
  value = length([
    for rule in azurerm_sentinel_alert_rule_ms_security_incident.rules : rule.id
    if rule.enabled
  ])
}

output "disabled_rules_count" {
  description = "Number of disabled Microsoft security rules"
  value = length([
    for rule in azurerm_sentinel_alert_rule_ms_security_incident.rules : rule.id
    if !rule.enabled
  ])
}
