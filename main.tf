terraform {
  required_version = ">= 1.0"

  # Terraform Cloud Backend Configuration
  cloud {
    organization = "Kaibersec"

    workspaces {
      name = "sentinel-content"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  
  # Disable automatic resource provider registration
  # Service principal has limited permissions for security
  skip_provider_registration = true

  # These will be configured as environment variables in Terraform Cloud
  # ARM_CLIENT_ID
  # ARM_CLIENT_SECRET  
  # ARM_SUBSCRIPTION_ID
  # ARM_TENANT_ID
}

# Get infrastructure outputs from SentinelLab repository
data "terraform_remote_state" "infrastructure" {
  backend = "remote"
  
  config = {
    organization = "kaibersec"
    workspaces = {
      name = "sentinellab-${var.environment}"
    }
  }
}

# Use infrastructure outputs from remote state
locals {
  workspace_id                    = data.terraform_remote_state.infrastructure.outputs.workspace_id
  workspace_ids                   = { primary = data.terraform_remote_state.infrastructure.outputs.workspace_id }  # Create map from single workspace
  resource_group_name             = data.terraform_remote_state.infrastructure.outputs.resource_group_name
  log_analytics_workspace_name    = var.log_analytics_workspace_name
  # Use a data source to get location since it's not in remote state outputs yet
  location                        = data.azurerm_resource_group.infrastructure_rg.location
}

# Data source to get location information
data "azurerm_resource_group" "infrastructure_rg" {
  name = data.terraform_remote_state.infrastructure.outputs.resource_group_name
}

# Custom Tables Module - MUST run before Data Collection Module
module "custom_tables" {
  count  = var.enable_data_collection && length(var.custom_tables) > 0 ? 1 : 0
  source = "./modules/custom-tables"
  
  resource_group_name = local.resource_group_name
  workspace_name     = local.log_analytics_workspace_name
  custom_tables      = var.custom_tables
  tags              = var.deployment_tags
}

# Data Collection Module - depends on custom tables
module "data_collection" {
  count  = var.enable_data_collection ? 1 : 0
  source = "./modules/data-collection"
  
  # Explicit dependency on custom tables
  depends_on = [module.custom_tables]
  
  resource_group_name = local.resource_group_name
  location           = local.location
  workspace_id       = local.workspace_id
  workspace_ids      = local.workspace_ids
  dce_configs        = var.dce_configs
  dcr_configs        = var.dcr_configs
  tags              = var.deployment_tags
}

# Data Connectors Module  
module "data_connectors" {
  count  = var.enable_data_connectors ? 1 : 0
  source = "./modules/data-connectors"
  
  workspace_id      = local.workspace_id
  connector_configs = var.connector_configs
}
