# Scheduled Analytics Rules Module
# This module creates scheduled analytics rules for Microsoft Sentinel

locals {
  # Process rules using individual configurations only
  processed_rules = {
    for rule_key, rule_config in var.scheduled_rules : rule_key => {
      display_name                = rule_config.display_name
      description                = coalesce(rule_config.description, "Managed by SentinelDaC Framework")
      severity                   = rule_config.severity
      enabled                    = rule_config.enabled
      query                      = rule_config.query
      query_frequency           = rule_config.query_frequency
      query_period              = rule_config.query_period
      trigger_operator          = coalesce(rule_config.trigger_operator, "GreaterThan")
      trigger_threshold         = coalesce(rule_config.trigger_threshold, 0)
      suppression_enabled       = coalesce(rule_config.suppression_enabled, false)
      suppression_duration      = coalesce(rule_config.suppression_duration, "PT1H")
      tactics                   = coalesce(rule_config.tactics, [])
      techniques                = coalesce(rule_config.techniques, [])
      alert_rule_template_guid  = rule_config.alert_rule_template_guid
      alert_rule_template_version = rule_config.alert_rule_template_version
      custom_details            = coalesce(rule_config.custom_details, {})
      entity_mappings          = coalesce(rule_config.entity_mappings, [])
      incident_configuration   = rule_config.incident_configuration
      event_grouping           = rule_config.event_grouping
      alert_details_override   = rule_config.alert_details_override
      tags                     = merge(var.deployment_tags, coalesce(rule_config.tags, {}))
    }
  }
}

# Create scheduled analytics rules
resource "azurerm_sentinel_alert_rule_scheduled" "rules" {
  for_each = local.processed_rules

  name                       = each.value.display_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name              = each.value.display_name
  description               = each.value.description
  severity                  = each.value.severity
  enabled                   = each.value.enabled
  query                     = each.value.query
  query_frequency          = each.value.query_frequency
  query_period             = each.value.query_period
  trigger_operator         = each.value.trigger_operator
  trigger_threshold        = each.value.trigger_threshold
  suppression_enabled      = each.value.suppression_enabled
  suppression_duration     = each.value.suppression_duration
  tactics                  = each.value.tactics
  techniques               = each.value.techniques
  
  # Optional template reference - only set version if GUID is also present
  alert_rule_template_guid    = each.value.alert_rule_template_guid
  alert_rule_template_version = each.value.alert_rule_template_guid != null ? each.value.alert_rule_template_version : null

  # Custom details for enrichment (stored as map)
  custom_details = each.value.custom_details

  # Entity mappings for linking alerts to entities
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

  # Incident configuration (updated from deprecated incident_configuration)
  dynamic "incident" {
    for_each = each.value.incident_configuration != null ? [each.value.incident_configuration] : []
    content {
      create_incident_enabled = incident.value.create_incident
      
      grouping {
        enabled                = lookup(incident.value, "grouping_enabled", false)
        lookback_duration     = lookup(incident.value, "lookback_duration", "P7D")
        entity_matching_method = lookup(incident.value, "entity_matching_method", "AnyAlert")
      }
    }
  }

  # Event grouping configuration
  dynamic "event_grouping" {
    for_each = each.value.event_grouping != null ? [each.value.event_grouping] : []
    content {
      aggregation_method = event_grouping.value.aggregation_method
    }
  }

  # Alert details override
  dynamic "alert_details_override" {
    for_each = each.value.alert_details_override != null ? [each.value.alert_details_override] : []
    content {
      description_format   = alert_details_override.value.description_format
      display_name_format  = alert_details_override.value.display_name_format
      severity_column_name = alert_details_override.value.severity_column_name
      tactics_column_name  = alert_details_override.value.tactics_column_name
    }
  }

  depends_on = [
    # Ensure Sentinel is onboarded before creating rules
  ]
}
