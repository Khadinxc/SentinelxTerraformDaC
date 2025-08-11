# Variables for NRT Rules Module

variable "nrt_rules" {
  description = "Map of NRT (Near Real Time) rule configurations"
  type = map(object({
    display_name                = string
    description                 = optional(string)
    severity                    = string
    enabled                     = optional(bool, true)
    query                       = string
    suppression_enabled         = optional(bool, false)
    suppression_duration        = optional(string, "PT1H")
    tactics                     = optional(list(string), [])
    techniques                  = optional(list(string), [])
    alert_rule_template_guid    = optional(string)
    alert_rule_template_version = optional(string)
    custom_details              = optional(map(string), {})
    entity_mappings = optional(list(object({
      entity_type = string
      field_mappings = list(object({
        identifier  = string
        column_name = string
      }))
    })), [])
    incident_configuration = optional(object({
      create_incident_enabled = bool
      grouping = optional(object({
        enabled                = bool
        lookback_duration      = string
        entity_matching_method = string
      }))
    }))
    event_grouping = optional(object({
      aggregation_method = string
    }), { aggregation_method = "SingleAlert" })
    alert_details_override = optional(object({
      description_format   = optional(string)
      display_name_format  = optional(string)
      severity_column_name = optional(string)
      tactics_column_name  = optional(string)
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace where Sentinel is deployed"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
