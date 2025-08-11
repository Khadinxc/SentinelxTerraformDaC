# Create custom tables in Log Analytics workspace for DCR ingestion
# These must be created BEFORE the corresponding DCRs

terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

resource "azapi_resource" "custom_tables" {
  for_each = var.custom_tables

  type      = "Microsoft.OperationalInsights/workspaces/tables@2022-10-01"
  name      = each.value.name
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.OperationalInsights/workspaces/${var.workspace_name}"

  body = jsonencode({
    properties = {
      schema = {
        name        = each.value.name
        description = each.value.description
        columns = each.value.columns
      }
      retentionInDays = each.value.retention_days
      plan           = "Analytics"
    }
  })
}

# Data source to get current configuration
data "azurerm_client_config" "current" {}
