# Outputs for the automation rules module
output "automation_rule_details" {
  description = "Details of created automation rules"
  value = {
    for key, rule in azurerm_sentinel_automation_rule.rules : key => {
      id           = rule.id
      name         = rule.name
      display_name = rule.display_name
      enabled      = rule.enabled
      order        = rule.order
    }
  }
}

output "automation_rules_count" {
  description = "Number of automation rules deployed"
  value       = length(azurerm_sentinel_automation_rule.rules)
}
