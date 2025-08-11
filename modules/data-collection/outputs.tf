# Data Collection Endpoints outputs
output "dce_ids" {
  description = "Map of all configured DCE IDs"
  value = {
    for k, v in azurerm_monitor_data_collection_endpoint.dces : k => v.id
  }
}

output "dce_names" {
  description = "Map of all configured DCE names"
  value = {
    for k, v in azurerm_monitor_data_collection_endpoint.dces : k => v.name
  }
}

output "dce_endpoints" {
  description = "Map of DCE configuration endpoint URLs"
  value = {
    for k, v in azurerm_monitor_data_collection_endpoint.dces : k => v.configuration_access_endpoint
  }
}

output "dce_logs_ingestion_endpoints" {
  description = "Map of DCE logs ingestion endpoint URLs"
  value = {
    for k, v in azurerm_monitor_data_collection_endpoint.dces : k => v.logs_ingestion_endpoint
  }
}

# Primary DCR outputs (for backward compatibility - uses first DCR from dcr_configs)
output "dcr_id" {
  description = "Primary Data Collection Rule ID"
  value       = length(azurerm_monitor_data_collection_rule.dcrs) > 0 ? values(azurerm_monitor_data_collection_rule.dcrs)[0].id : null
}

output "dcr_name" {
  description = "Primary Data Collection Rule name"
  value       = length(azurerm_monitor_data_collection_rule.dcrs) > 0 ? values(azurerm_monitor_data_collection_rule.dcrs)[0].name : null
}

# Scalable outputs
output "dcr_ids" {
  description = "Map of all configured DCR IDs"
  value = {
    for k, v in azurerm_monitor_data_collection_rule.dcrs : k => v.id
  }
}

output "dcr_names" {
  description = "Map of all configured DCR names"
  value = {
    for k, v in azurerm_monitor_data_collection_rule.dcrs : k => v.name
  }
}
