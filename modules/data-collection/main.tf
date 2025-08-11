# Data Collection Endpoints for API-based data ingestion
resource "azurerm_monitor_data_collection_endpoint" "dces" {
  for_each = var.dce_configs
  
  name                          = each.value.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  description                  = each.value.description
  public_network_access_enabled = each.value.public_network_access_enabled

  tags = var.tags
}

# Scalable DCR resources with multi-destination support and parser configuration
resource "azurerm_monitor_data_collection_rule" "dcrs" {
  for_each = var.dcr_configs
  
  name                = each.value.name
  resource_group_name = var.resource_group_name
  location            = var.location
  
  # Note: API ingestion DCRs work without explicit kind parameter in Terraform

  # Associate with Data Collection Endpoint if specified
  data_collection_endpoint_id = each.value.data_collection_endpoint_key != null ? azurerm_monitor_data_collection_endpoint.dces[each.value.data_collection_endpoint_key].id : null

  # Dynamic destinations based on DCR configuration
  dynamic "destinations" {
    for_each = each.value.destinations
    content {
      log_analytics {
        workspace_resource_id = destinations.value == "primary" ? var.workspace_id : var.workspace_ids[destinations.value]
        name                  = "${destinations.value}-dest"
      }
    }
  }

  # Define custom streams if stream declarations are provided
  dynamic "stream_declaration" {
    for_each = each.value.stream_declarations
    content {
      stream_name = stream_declaration.key
      dynamic "column" {
        for_each = stream_declaration.value.columns
        content {
          name = column.value.name
          type = column.value.type
        }
      }
    }
  }

  data_flow {
    streams = (
      each.value.data_type == "syslog" ? ["Microsoft-Syslog"] :
      each.value.data_type == "windows_event_log" ? ["Microsoft-WindowsEvent"] :
      each.value.data_type == "custom" && length(each.value.stream_declarations) > 0 ? [for k, v in each.value.stream_declarations : k] :
      each.value.data_type == "custom" && length(each.value.stream_declarations) == 0 ? ["Microsoft-Table-Custom"] :
      ["Microsoft-Syslog"]  # Default fallback
    )
    destinations = [for dest in each.value.destinations : "${dest}-dest"]
    # Apply transformation if provided - only for custom data types with DCE
    transform_kql = (each.value.transform_kql != null && each.value.data_type == "custom") ? each.value.transform_kql : null
    output_stream = each.value.output_stream
  }

  # Dynamic data sources based on type (not needed for custom API-based ingestion)
  dynamic "data_sources" {
    for_each = each.value.data_type == "syslog" ? [1] : []
    content {
      syslog {
        facility_names = each.value.facilities
        log_levels     = each.value.log_levels
        name          = "${each.key}DataSource"
        streams       = each.value.output_stream != null ? [each.value.output_stream] : ["Microsoft-Syslog"]
      }
    }
  }

  dynamic "data_sources" {
    for_each = each.value.data_type == "windows_event_log" ? [1] : []
    content {
      windows_event_log {
        name           = "${each.key}DataSource"
        streams        = each.value.output_stream != null ? [each.value.output_stream] : ["Microsoft-WindowsEvent"]
        x_path_queries = [for facility in each.value.facilities : "${facility}!*[System[Level <= 4]]"]
      }
    }
  }

  tags = var.tags
}
