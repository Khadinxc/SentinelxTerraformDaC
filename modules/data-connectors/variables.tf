variable "workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
}

# Scalable connector configuration
variable "connector_configs" {
  description = "Configuration for multiple data connectors"
  type = map(object({
    name            = string
    type            = string
    enabled         = bool
    exchange_enabled   = optional(bool, false)
    sharepoint_enabled = optional(bool, false)
    teams_enabled     = optional(bool, false)
    date            = optional(string, null)  # Optional date for connectors that require it
  }))
  default = {}
}
