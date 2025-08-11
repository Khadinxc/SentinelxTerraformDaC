# Variables for the scheduled analytics rules module
variable "resource_group_name" {
  description = "Name of the resource group containing Sentinel resources"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "deployment_tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "scheduled_rules" {
  description = "Map of scheduled analytics rules to deploy"
  type = map(object({
    display_name                = string
    description                = optional(string, "")
    severity                   = string
    enabled                    = bool
    query                      = string
    query_frequency           = string
    query_period              = string
    trigger_operator          = optional(string, "GreaterThan")
    trigger_threshold         = optional(number, 0)
    suppression_enabled       = optional(bool, false)
    suppression_duration      = optional(string, "PT1H")
    tactics                   = optional(list(string), [])
    techniques                = optional(list(string), [])
    alert_rule_template_guid  = optional(string)
    alert_rule_template_version = optional(string)
    custom_details            = optional(map(string), {})
    entity_mappings = optional(list(object({
      entity_type = string
      field_mappings = list(object({
        identifier  = string
        column_name = string
      }))
    })), [])
    incident_configuration = optional(object({
      create_incident        = optional(bool, true)
      grouping_enabled      = optional(bool, false)
      reopen_closed_incident = optional(bool, false)
      lookback_duration     = optional(string, "PT5H")
      entity_matching_method = optional(string, "AnyAlert")
      group_by_entities     = optional(list(string), [])
      group_by_alert_details = optional(list(string), [])
      group_by_custom_details = optional(list(string), [])
    }))
    event_grouping = optional(object({
      aggregation_method = optional(string, "SingleAlert")
    }))
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
