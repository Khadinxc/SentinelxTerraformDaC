# Automation Rules Module
# This module creates Microsoft Sentinel Automation Rules

locals {
  # Process automation rules with defaults
  processed_rules = {
    for rule_key, rule_config in var.automation_rules : rule_key => {
      display_name    = rule_config.display_name
      description     = coalesce(rule_config.description, "Managed by SentinelDaC Framework")
      enabled         = coalesce(rule_config.enabled, true)
      order           = coalesce(rule_config.order, 1000)
      expiration      = rule_config.expiration
      conditions      = rule_config.conditions
      actions         = rule_config.actions
      incident_configuration = rule_config.incident_configuration
      tags            = merge(var.common_tags, coalesce(rule_config.tags, {}))
    } if coalesce(rule_config.enabled, true) == true
  }
}

# Create Sentinel Automation Rules
resource "azurerm_sentinel_automation_rule" "rules" {
  for_each = local.processed_rules

  name                       = uuidv5("dns", each.key)  # Generate UUID from key
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = each.value.display_name
  order                      = each.value.order
  enabled                    = each.value.enabled
  
  # Optional expiration
  expiration = each.value.expiration

  # Conditions for rule triggering (updated to use condition_json with proper Azure format)
  condition_json = jsonencode([
    for condition in each.value.conditions : {
      conditionType = "Property"
      conditionProperties = {
        propertyName   = condition.property
        operator       = condition.operator
        propertyValues = condition.values
      }
    }
  ])

  # Actions to perform when conditions are met
  dynamic "action_incident" {
    for_each = [for action in each.value.actions : action if action.action_type == "ModifyProperties"]
    content {
      order                      = action_incident.value.order
      status                     = try(action_incident.value.status, null)
      classification             = try(action_incident.value.classification, null)
      classification_comment     = try(action_incident.value.classification_comment, null)
      # owner_id requires Azure AD Object ID format (GUID), not email
      # owner_id                   = try(action_incident.value.assignee, null)
      severity                   = try(action_incident.value.severity, null)
      labels                     = try(action_incident.value.labels, null)
    }
  }

  dynamic "action_playbook" {
    for_each = [for action in each.value.actions : action if action.action_type == "RunPlaybook"]
    content {
      order           = action_playbook.value.order
      logic_app_id    = action_playbook.value.logic_app_resource_id
      tenant_id       = try(action_playbook.value.tenant_id, null)
    }
  }

  depends_on = [
    # Ensure Log Analytics workspace exists
  ]
}
