# NRT (Near Real Time) Rules Module
# This module creates Sentinel NRT Alert Rules for immediate threat detection

locals {
  # Process NRT rules with defaults
  processed_nrt_rules = {
    for rule_key, rule_config in var.nrt_rules : rule_key => {
      display_name                = rule_config.display_name
      description                 = coalesce(rule_config.description, "Managed by SentinelDaC Framework")
      severity                    = rule_config.severity
      enabled                     = coalesce(rule_config.enabled, true)
      query                       = rule_config.query
      suppression_enabled         = coalesce(rule_config.suppression_enabled, false)
      suppression_duration        = coalesce(rule_config.suppression_duration, "PT1H")
      tactics                     = coalesce(rule_config.tactics, [])
      techniques                  = coalesce(rule_config.techniques, [])
      alert_rule_template_guid    = lookup(rule_config, "alert_rule_template_guid", null)
      alert_rule_template_version = lookup(rule_config, "alert_rule_template_version", null)
      custom_details              = coalesce(rule_config.custom_details, {})
      entity_mappings             = coalesce(rule_config.entity_mappings, [])
      incident_configuration      = lookup(rule_config, "incident_configuration", null)
      event_grouping              = coalesce(rule_config.event_grouping, { aggregation_method = "SingleAlert" })
      alert_details_override      = lookup(rule_config, "alert_details_override", null)
      tags                        = merge(var.common_tags, coalesce(rule_config.tags, {}))
    } if coalesce(rule_config.enabled, true) == true
  }
}

# Create Sentinel NRT Alert Rules
resource "azurerm_sentinel_alert_rule_nrt" "rules" {
  for_each = local.processed_nrt_rules

  name                       = each.key
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = each.value.display_name
  description                = each.value.description
  severity                   = each.value.severity
  enabled                    = each.value.enabled
  query                      = each.value.query
  
  # Suppression configuration
  suppression_enabled  = each.value.suppression_enabled
  suppression_duration = each.value.suppression_duration

  # MITRE ATT&CK framework
  tactics    = each.value.tactics
  techniques = each.value.techniques

  # Template references (if based on existing templates) - only set version if GUID is also present
  alert_rule_template_guid    = each.value.alert_rule_template_guid
  alert_rule_template_version = each.value.alert_rule_template_guid != null ? each.value.alert_rule_template_version : null

  # Entity mappings for threat intelligence
  dynamic "entity_mapping" {
    for_each = each.value.entity_mappings
    content {
      entity_type = entity_mapping.value.entity_type
      dynamic "field_mapping" {
        for_each = entity_mapping.value.field_mappings
        content {
          identifier  = field_mapping.value.identifier
          column_name = field_mapping.value.column_name
        }
      }
    }
  }

  # Incident configuration (simplified for NRT rules)
  dynamic "incident" {
    for_each = each.value.incident_configuration != null ? [each.value.incident_configuration] : []
    content {
      create_incident_enabled = incident.value.create_incident_enabled
      
      dynamic "grouping" {
        for_each = lookup(incident.value, "grouping", null) != null ? [incident.value.grouping] : []
        content {
          enabled                 = lookup(grouping.value, "enabled", false)
          lookback_duration       = lookup(grouping.value, "lookback_duration", "PT5M")
          entity_matching_method  = lookup(grouping.value, "entity_matching_method", "All")
        }
      }
    }
  }

  # Event grouping configuration
  dynamic "event_grouping" {
    for_each = [each.value.event_grouping]
    content {
      aggregation_method = event_grouping.value.aggregation_method
    }
  }

  # Alert details override
  dynamic "alert_details_override" {
    for_each = each.value.alert_details_override != null ? [each.value.alert_details_override] : []
    content {
      description_format   = lookup(alert_details_override.value, "description_format", null)
      display_name_format  = lookup(alert_details_override.value, "display_name_format", null)
      severity_column_name = lookup(alert_details_override.value, "severity_column_name", null)
      tactics_column_name  = lookup(alert_details_override.value, "tactics_column_name", null)
    }
  }
}
