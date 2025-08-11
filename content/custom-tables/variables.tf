variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "custom_tables" {
  description = "Map of custom tables to create"
  type = map(object({
    name        = string
    description = optional(string, "Custom table for DCR ingestion")
    columns = list(object({
      name = string
      type = string
    }))
    retention_days = optional(number, 30)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
