# Watchlists Module Variables

variable "watchlists" {
  description = "Map of watchlists to create"
  type = map(object({
    display_name = string
    description  = optional(string)
    source       = string
    search_key   = string
    enabled      = optional(bool, true)
    items        = optional(list(map(string)), [])
    tags         = optional(map(string), {})
  }))
  default = {}
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID where watchlists will be deployed"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
