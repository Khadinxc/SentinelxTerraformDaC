# Variables for the Microsoft security rules module
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

variable "microsoft_rules" {
  description = "Map of Microsoft security rules to deploy"
  type = map(object({
    display_name                = string
    description                = optional(string, "")
    enabled                    = optional(bool, true)
    alert_rule_template_guid   = string
    alert_rule_template_version = optional(string, "1.0.0")
    product_filter             = optional(string, "Microsoft Cloud App Security")
  }))
  default = {}
}
