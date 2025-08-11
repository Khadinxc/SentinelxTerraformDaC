# Watchlists Module
# This module creates Sentinel Watchlists for threat intelligence and allow/blocklists

locals {
  # Process watchlists with defaults
  processed_watchlists = {
    for watchlist_key, watchlist_config in var.watchlists : watchlist_key => {
      display_name           = watchlist_config.display_name
      description            = coalesce(watchlist_config.description, "Managed by SentinelDaC Framework")
      enabled                = coalesce(watchlist_config.enabled, true)
      source                 = watchlist_config.source
      search_key             = watchlist_config.search_key
      items                  = coalesce(watchlist_config.items, [])
      tags                   = merge(var.common_tags, coalesce(watchlist_config.tags, {}))
    } if coalesce(watchlist_config.enabled, true) == true
  }

  # Flatten watchlist items for individual resource creation
  watchlist_items = merge([
    for watchlist_key, watchlist_config in local.processed_watchlists : {
      for idx, item in watchlist_config.items : "${watchlist_key}-${idx}" => {
        watchlist_key = watchlist_key
        item_uuid     = uuidv5("dns", "${watchlist_key}-${idx}")
        properties    = item
      }
    }
  ]...)
}

# Create Sentinel Watchlists
resource "azurerm_sentinel_watchlist" "watchlists" {
  for_each = local.processed_watchlists

  name                         = each.key
  log_analytics_workspace_id   = var.log_analytics_workspace_id
  display_name                 = each.value.display_name
  description                  = each.value.description
  item_search_key              = each.value.search_key
}

# Create Sentinel Watchlist Items
resource "azurerm_sentinel_watchlist_item" "watchlist_items" {
  for_each = local.watchlist_items

  name         = each.value.item_uuid
  watchlist_id = azurerm_sentinel_watchlist.watchlists[each.value.watchlist_key].id
  properties   = {
    for key, value in each.value.properties : key => tostring(value)
  }
}
