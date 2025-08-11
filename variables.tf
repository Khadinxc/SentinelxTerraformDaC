# Core Infrastructure Variables
variable "subscription_id" {
  description = "Azure subscription ID for kaiber-management"
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Resource group containing Sentinel infrastructure"
  type        = string
  default     = "rg-sentinel-dev"
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics workspace name where Sentinel is deployed"
  type        = string
  default     = "law-sentinel-dev"
}

# Environment Configuration
variable "environment" {
  description = "Environment name for this deployment"
  type        = string
  default     = "dev"
}

# Deployment Tags
variable "deployment_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "SentinelDaC"
    ManagedBy   = "Terraform"
    Framework   = "Detection-as-Code"
    Version     = "v3.0"
  }
}

# Content Management Variables
variable "enable_scheduled_rules" {
  description = "Enable deployment of scheduled analytics rules"
  type        = bool
  default     = true
}

variable "enable_nrt_rules" {
  description = "Enable deployment of NRT (Near Real Time) rules"
  type        = bool
  default     = true
}

# DEPRECATED: Fusion rules removed - being phased out in Defender portal migration
# variable "enable_fusion_rules" {
#   description = "Enable deployment of fusion rules"
#   type        = bool
#   default     = false
# }

variable "enable_microsoft_rules" {
  description = "Enable deployment of Microsoft security rules"
  type        = bool
  default     = true
}

# Phase 2 Configuration Variables
variable "enable_playbooks" {
  description = "Enable deployment of playbooks (Logic Apps)"
  type        = bool
  default     = false  # Disabled by default for Phase 2 rollout
}

variable "enable_hunting_queries" {
  description = "Enable deployment of hunting queries"
  type        = bool
  default     = false  # Disabled by default for Phase 2 rollout
}

# Rule Configuration
variable "custom_rule_prefix" {
  description = "Prefix for custom rule names to avoid conflicts"
  type        = string
  default     = "Custom"
}

# Phase 4 Variables (for future use)
variable "enable_automation_rules" {
  description = "Enable deployment of automation rules (Phase 4)"
  type        = bool
  default     = false
}

variable "enable_watchlists" {
  description = "Enable deployment of watchlists for enrichment"
  type        = bool
  default     = false
}

# Automation Account Configuration
variable "automation_account_name" {
  description = "Name of the existing Azure Automation Account for script-based playbooks"
  type        = string
  default     = ""
}

# Data Collection and Connectors Configuration
variable "enable_data_collection" {
  description = "Enable deployment of data collection rules"
  type        = bool
  default     = true
}

variable "enable_data_connectors" {
  description = "Enable deployment of data connectors"
  type        = bool
  default     = true
}

variable "custom_tables" {
  description = "Custom tables to create in Log Analytics workspace for DCR ingestion"
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

variable "dce_configs" {
  description = "Data Collection Endpoints configuration"
  type        = any
  default     = {}
}

variable "dcr_configs" {
  description = "Data Collection Rules configuration"
  type        = any
  default     = {}
}

variable "connector_configs" {
  description = "Data Connectors configuration"
  type        = any
  default     = {}
}
