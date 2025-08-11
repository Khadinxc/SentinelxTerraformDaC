# Primary connector outputs (for backward compatibility - uses first connector of each type)
output "aad_connector_id" {
  description = "Primary Azure AD data connector ID"
  value       = length([for k, v in azurerm_sentinel_data_connector_azure_active_directory.connectors_aad : v.id]) > 0 ? values(azurerm_sentinel_data_connector_azure_active_directory.connectors_aad)[0].id : null
}

output "o365_connector_id" {
  description = "Primary Office 365 data connector ID"
  value       = length([for k, v in azurerm_sentinel_data_connector_office_365.connectors_o365 : v.id]) > 0 ? values(azurerm_sentinel_data_connector_office_365.connectors_o365)[0].id : null
}

output "azure_activity_connector_id" {
  description = "Azure Activity data connector ID (placeholder - resource not yet available)"
  value       = null
}

output "mti_connector_id" {
  description = "Primary Microsoft Threat Intelligence data connector ID"
  value       = length([for k, v in azurerm_sentinel_data_connector_microsoft_threat_intelligence.connectors_mti : v.id]) > 0 ? values(azurerm_sentinel_data_connector_microsoft_threat_intelligence.connectors_mti)[0].id : null
}

# Scalable outputs
output "connector_ids" {
  description = "Map of all configured data connector IDs"
  value = merge(
    {
      for k, v in azurerm_sentinel_data_connector_azure_active_directory.connectors_aad : k => v.id
    },
    {
      for k, v in azurerm_sentinel_data_connector_office_365.connectors_o365 : k => v.id
    },
    {
      for k, v in azurerm_sentinel_data_connector_microsoft_threat_intelligence.connectors_mti : k => v.id
    }
  )
}

output "connector_names" {
  description = "Map of all configured data connector names"
  value = merge(
    {
      for k, v in azurerm_sentinel_data_connector_azure_active_directory.connectors_aad : k => v.name
    },
    {
      for k, v in azurerm_sentinel_data_connector_office_365.connectors_o365 : k => v.name
    },
    {
      for k, v in azurerm_sentinel_data_connector_microsoft_threat_intelligence.connectors_mti : k => v.name
    }
  )
}
