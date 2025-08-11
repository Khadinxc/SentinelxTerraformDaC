# Variables for the automation rules module
variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "automation_rules" {
  description = "Map of automation rules to deploy"
  type = map(object({
    display_name    = string
    description     = optional(string, "Managed by SentinelDaC")
    enabled         = optional(bool, true)
    order           = optional(number, 1000)
    expiration      = optional(string, null)
    conditions      = list(object({
      property        = string        # IncidentTitle, IncidentDescription, IncidentSeverity, etc.
      operator        = string        # Equals, NotEquals, Contains, etc.
      values          = list(string)
    }))
    actions = list(object({
      order = number
      action_type = string  # ModifyProperties, RunPlaybook
      # For ModifyProperties
      severity     = optional(string)
      status       = optional(string)
      assignee     = optional(string)
      classification = optional(string)
      classification_comment = optional(string)
      classification_reason  = optional(string)
      labels       = optional(list(string))
      # For RunPlaybook
      logic_app_resource_id = optional(string)
      tenant_id            = optional(string)
    }))
    incident_configuration = optional(object({
      create_incident = optional(bool, true)
      grouping = optional(object({
        enabled                 = optional(bool, false)
        reopen_closed_incident  = optional(bool, false)
        lookback_duration       = optional(string, "PT5H")
        entity_matching_method  = optional(string, "AllEntities")
        group_by_entities       = optional(list(string), [])
        group_by_alert_details  = optional(list(string), [])
        group_by_custom_details = optional(list(string), [])
      }))
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}
