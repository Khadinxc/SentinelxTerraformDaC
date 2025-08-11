# Watchlists Module Outputs

output "watchlists" {
  description = "Map of deployed watchlists"
  value = {
    for k, v in azurerm_sentinel_watchlist.watchlists : k => {
      id            = v.id
      name          = v.name
      display_name  = v.display_name
      description   = v.description
      search_key    = v.item_search_key
    }
  }
}

output "watchlist_items" {
  description = "Map of deployed watchlist items"
  value = {
    for k, v in azurerm_sentinel_watchlist_item.watchlist_items : k => {
      id           = v.id
      name         = v.name
      watchlist_id = v.watchlist_id
      properties   = v.properties
    }
  }
}

output "watchlists_count" {
  description = "Number of watchlists deployed"
  value       = length(azurerm_sentinel_watchlist.watchlists)
}

output "watchlist_items_count" {
  description = "Number of watchlist items deployed"
  value       = length(azurerm_sentinel_watchlist_item.watchlist_items)
}
