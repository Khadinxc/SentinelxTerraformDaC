# Outputs for integration with other workspaces and debugging
output "resource_group_name" {
  description = "Name of the resource group containing Sentinel resources"
  value       = local.resource_group_name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = local.workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = var.log_analytics_workspace_name
}

# Analytics Rules Outputs
output "scheduled_analytics_rules" {
  description = "Details of deployed scheduled analytics rules"
  value       = var.enable_scheduled_rules ? module.scheduled_analytics_rules[0].rule_details : {}
  sensitive   = false
}

output "scheduled_rules_count" {
  description = "Number of scheduled analytics rules deployed"
  value       = var.enable_scheduled_rules ? length(module.scheduled_analytics_rules[0].rule_details) : 0
}

# Fusion Rules Outputs
# DEPRECATED: Fusion rules outputs removed - being phased out in Defender portal migration
# output "fusion_rules" {
#   description = "Details of deployed fusion rules"
#   value       = var.enable_fusion_rules ? module.fusion_rules[0].rule_details : {}
#   sensitive   = false
# }

# output "fusion_rules_count" {
#   description = "Number of fusion rules deployed"
#   value       = var.enable_fusion_rules ? length(module.fusion_rules[0].rule_details) : 0
# }

# Microsoft Rules Outputs
output "microsoft_rules" {
  description = "Details of deployed Microsoft security rules"
  value       = var.enable_microsoft_rules ? module.microsoft_rules[0].rule_details : {}
  sensitive   = false
}

output "microsoft_rules_count" {
  description = "Number of Microsoft security rules deployed"
  value       = var.enable_microsoft_rules ? length(module.microsoft_rules[0].rule_details) : 0
}

# Playbooks Outputs
output "playbooks" {
  description = "Details of deployed playbooks (both Logic Apps and Scripts)"
  value       = var.enable_playbooks ? module.playbooks[0].all_playbook_references : {}
  sensitive   = true
}

output "playbooks_count" {
  description = "Number of playbooks deployed"
  value       = var.enable_playbooks ? length(module.playbooks[0].all_playbook_references) : 0
}

# Data Collection Endpoints Outputs
output "data_collection_endpoints" {
  description = "Details of deployed data collection endpoints"
  value       = var.enable_data_collection ? module.data_collection[0].dce_ids : {}
  sensitive   = false
}

output "data_collection_endpoints_urls" {
  description = "API ingestion URLs for data collection endpoints"
  value       = var.enable_data_collection ? module.data_collection[0].dce_logs_ingestion_endpoints : {}
  sensitive   = false
}

output "data_collection_endpoints_count" {
  description = "Number of data collection endpoints deployed"
  value       = var.enable_data_collection ? length(module.data_collection[0].dce_ids) : 0
}

# Data Collection Rules Outputs
output "data_collection_rules" {
  description = "Details of deployed data collection rules"
  value       = var.enable_data_collection ? module.data_collection[0].dcr_ids : {}
  sensitive   = false
}

output "data_collection_rules_count" {
  description = "Number of data collection rules deployed"
  value       = var.enable_data_collection ? length(module.data_collection[0].dcr_ids) : 0
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of deployed detection content"
  value = {
    environment           = var.environment
    scheduled_rules_count = var.enable_scheduled_rules ? length(module.scheduled_analytics_rules[0].rule_details) : 0
    # DEPRECATED: fusion_rules_count = 0 (fusion rules removed)
    microsoft_rules_count = var.enable_microsoft_rules ? length(module.microsoft_rules[0].rule_details) : 0
    data_collection_rules_count = var.enable_data_collection ? length(module.data_collection[0].dcr_ids) : 0
    data_collection_endpoints_count = var.enable_data_collection ? length(module.data_collection[0].dce_ids) : 0
    total_rules_deployed = (
      (var.enable_scheduled_rules ? length(module.scheduled_analytics_rules[0].rule_details) : 0) +
      # DEPRECATED: fusion rules count removed from total
      (var.enable_microsoft_rules ? length(module.microsoft_rules[0].rule_details) : 0)
    )
    deployment_timestamp = timestamp()
  }
}
