# Variables for the hunting queries module
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

variable "hunting_queries" {
  description = "Map of hunting queries to deploy"
  type = map(object({
    display_name = string
    description  = optional(string, "")
    enabled      = optional(bool, true)
    category     = optional(string, "General")
    severity     = optional(string, "Medium")
    query        = string
    tactics      = optional(list(string), [])
    techniques   = optional(list(string), [])
    data_sources = optional(list(string), [])
    references   = optional(list(string), [])
    tags         = optional(map(string), {})
  }))
  default = {}
}
