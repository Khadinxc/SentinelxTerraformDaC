# Scalable data connectors
# Azure Active Directory Data Connectors
resource "azurerm_sentinel_data_connector_azure_active_directory" "connectors_aad" {
  for_each = {
    for k, v in var.connector_configs : k => v
    if v.type == "azure_active_directory" && v.enabled
  }
  
  name                       = each.value.name
  log_analytics_workspace_id = var.workspace_id
}

# Office 365 Data Connectors
resource "azurerm_sentinel_data_connector_office_365" "connectors_o365" {
  for_each = {
    for k, v in var.connector_configs : k => v
    if v.type == "office_365" && v.enabled
  }
  
  name                       = each.value.name
  log_analytics_workspace_id = var.workspace_id
  
  exchange_enabled   = each.value.exchange_enabled
  sharepoint_enabled = each.value.sharepoint_enabled
  teams_enabled     = each.value.teams_enabled
}

resource "azurerm_sentinel_data_connector_microsoft_threat_intelligence" "connectors_mti" {
  for_each = {
    for k, v in var.connector_configs : k => v
    if v.type == "microsoft_threat_intelligence" && v.enabled
  }
  
  name                       = each.value.name
  log_analytics_workspace_id = var.workspace_id
  microsoft_emerging_threat_feed_lookback_date = each.value.date
  depends_on = [ var.workspace_id ]
}

# Future: Azure Activity Data Connectors (when resource becomes available)
# resource "azurerm_sentinel_data_connector_azure_activity_log" "connectors_activity" {
#   for_each = {
#     for k, v in var.connector_configs : k => v
#     if v.type == "azure_activity" && v.enabled
#   }
#   
#   name                       = each.value.name
#   log_analytics_workspace_id = var.workspace_id
# }
