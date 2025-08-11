# Hunting Queries Module
# This module creates custom hunting queries for Microsoft Sentinel

locals {
  # Process hunting queries with defaults
  processed_queries = {
    for query_key, query_config in var.hunting_queries : query_key => {
      display_name    = query_config.display_name
      description     = coalesce(query_config.description, "Managed by SentinelDaC Framework - Hunting Query")
      enabled         = coalesce(query_config.enabled, true)
      category        = coalesce(query_config.category, "General")
      severity        = coalesce(query_config.severity, "Medium")
      query           = query_config.query
      tactics         = coalesce(query_config.tactics, [])
      techniques      = coalesce(query_config.techniques, [])
      data_sources    = coalesce(query_config.data_sources, [])
      references      = coalesce(query_config.references, [])
      tags            = merge(var.deployment_tags, coalesce(query_config.tags, {}))
    }
  }
}

# Create hunting queries using saved searches (as Sentinel hunting queries use this mechanism)
resource "azurerm_log_analytics_saved_search" "hunting_queries" {
  for_each = local.processed_queries

  name                       = each.key
  log_analytics_workspace_id = var.log_analytics_workspace_id
  category                   = "Hunting Queries"
  display_name               = each.value.display_name
  query                      = each.value.query

  # Note: Log Analytics saved searches use a different tag format than other Azure resources
  # We'll include metadata in the query comments instead
  tags = {
    "HuntingQuery" = "true"
    "Severity"     = each.value.severity
    "Category"     = each.value.category
    "Purpose"      = "threat-hunting"
  }

  depends_on = [
    # Ensure Log Analytics workspace exists
  ]
}
