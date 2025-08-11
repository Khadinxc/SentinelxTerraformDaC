# Variables for the playbooks module
variable "resource_group_name" {
  description = "Name of the resource group containing Sentinel resources"
  type        = string
}

variable "location" {
  description = "Azure region for deployments"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "automation_account_name" {
  description = "Name of the existing Azure Automation Account for script-based playbooks"
  type        = string
  default     = ""
}

variable "playbooks" {
  description = "Map of playbooks to deploy (Logic Apps and Scripts)"
  type = map(object({
    name           = string
    description    = optional(string, "")
    enabled        = optional(bool, true)
    playbook_type  = string  # Incident, Notification, Investigation, Remediation
    execution_type = optional(string, "LogicApp")  # LogicApp or Script
    severity       = optional(string, "Medium")
    trigger_type   = string  # Sentinel, HTTP, Schedule, Manual
    author         = optional(string, "SentinelDaC")
    version        = optional(string, "1.0")
    
    # Script-specific settings (for execution_type = "Script")
    script_type    = optional(string, "PowerShell")  # PowerShell, Python, GraphPowerShell
    script_content = optional(string, "")
    parameters     = optional(map(string), {})
    
    # HTTP trigger specific settings
    http_schema = optional(map(object({
      type = string
    })), {})
    
    # Schedule trigger specific settings
    schedule_frequency = optional(string, "Day")  # Minute, Hour, Day, Week, Month
    schedule_interval  = optional(number, 1)
    schedule_time     = optional(string)  # Format: "HH:MM" for daily schedules
    
    # Playbook actions and workflow definition (for Logic Apps)
    actions = optional(list(object({
      name = string
      type = string
      inputs = map(any)
    })), [])
    
    # Tags for additional metadata
    tags = optional(map(string), {})
  }))
  default = {}
}
