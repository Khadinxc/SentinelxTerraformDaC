# Data Collection Endpoints configuration
variable "dce_configs" {
  description = "Configuration for Data Collection Endpoints (API ingestion endpoints)"
  type = map(object({
    name                           = string
    description                    = optional(string, null)
    public_network_access_enabled  = optional(bool, true)
  }))
  default = {}
}

# Scalable DCR configuration
variable "dcr_configs" {
  description = "Configuration for multiple Data Collection Rules"
  type = map(object({
    name         = string
    data_type    = string
    facilities   = list(string)
    log_levels   = list(string)
    destinations = optional(list(string), ["primary"])  # Default to primary workspace
    # Data Collection Endpoint association
    data_collection_endpoint_key = optional(string, null)  # Reference to DCE in dce_configs
    # Parser/Transformation Configuration
    stream_declarations = optional(map(object({
      columns = list(object({
        name = string
        type = string
      }))
    })), {})
    transform_kql = optional(string, null)  # KQL transformation query
    output_stream = optional(string, null)  # Custom output stream name
  }))
  default = {}
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "workspace_id" {
  description = "Primary Log Analytics workspace ID (for backward compatibility)"
  type        = string
}

# Enhanced multi-workspace support
variable "workspace_ids" {
  description = "Map of workspace names to their resource IDs"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
