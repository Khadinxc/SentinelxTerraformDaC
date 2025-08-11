# All infrastructure data now comes from remote state
# No local data sources needed

# Import modules for detection content - conditional deployment
module "scheduled_analytics_rules" {
  count  = var.enable_scheduled_rules ? 1 : 0
  source = "./modules/analytics-rules"

  resource_group_name          = local.resource_group_name
  log_analytics_workspace_name = var.log_analytics_workspace_name
  log_analytics_workspace_id   = local.workspace_id

  # Pass centralized variables
  environment            = var.environment
  deployment_tags        = var.deployment_tags

  # Content definitions
  scheduled_rules = local.scheduled_rules
}

module "nrt_rules" {
  count  = var.enable_nrt_rules ? 1 : 0
  source = "./modules/nrt-rules"

  log_analytics_workspace_id = local.workspace_id

  # Pass centralized variables
  common_tags = var.deployment_tags

  # Content definitions
  nrt_rules = local.nrt_rules
}

# DEPRECATED: Fusion rules module removed - being phased out in Defender portal migration
# module "fusion_rules" {
#   count  = var.enable_fusion_rules ? 1 : 0
#   source = "./modules/fusion-rules"
#
#   resource_group_name          = local.resource_group_name
#   log_analytics_workspace_name = var.log_analytics_workspace_name
#   log_analytics_workspace_id   = local.workspace_id
#
#   # Pass centralized variables
#   environment     = var.environment
#   deployment_tags = var.deployment_tags
#
#   # Content definitions
#   fusion_rules = local.fusion_rules
# }

module "microsoft_rules" {
  count  = var.enable_microsoft_rules ? 1 : 0
  source = "./modules/microsoft-rules"

  resource_group_name          = local.resource_group_name
  log_analytics_workspace_name = var.log_analytics_workspace_name
  log_analytics_workspace_id   = local.workspace_id

  # Pass centralized variables
  environment     = var.environment
  deployment_tags = var.deployment_tags

  # Content definitions
  microsoft_rules = local.microsoft_rules
}

# Phase 2 modules - Conditional deployment based on feature flags

module "automation_rules" {
  count  = var.enable_automation_rules ? 1 : 0
  source = "./modules/automation-rules"

  resource_group_name        = local.resource_group_name
  log_analytics_workspace_id = local.workspace_id
  location                   = local.location

  # Pass centralized variables
  common_tags = var.deployment_tags

  # Content definitions
  automation_rules = local.automation_rules
}

module "hunting_queries" {
  count  = var.enable_hunting_queries ? 1 : 0
  source = "./modules/hunting-queries"

  resource_group_name          = local.resource_group_name
  log_analytics_workspace_name = var.log_analytics_workspace_name
  log_analytics_workspace_id   = local.workspace_id

  # Pass centralized variables
  environment     = var.environment
  deployment_tags = var.deployment_tags

  # Content definitions
  hunting_queries = local.hunting_queries
}

module "playbooks" {
  count  = var.enable_playbooks ? 1 : 0
  source = "./modules/playbooks"

  resource_group_name     = local.resource_group_name
  location               = local.location
  automation_account_name = var.automation_account_name

  # Pass centralized variables
  common_tags = var.deployment_tags

  # Content definitions
  playbooks = local.playbooks
}

# Phase 3 modules - Watchlists
module "watchlists" {
  count  = var.enable_watchlists ? 1 : 0
  source = "./modules/watchlists"

  log_analytics_workspace_id = local.workspace_id

  # Pass centralized variables
  common_tags = var.deployment_tags

  # Content definitions
  watchlists = local.watchlists
}
