# Outputs for the hunting queries module
output "hunting_query_details" {
  description = "Details of created hunting queries"
  value = {
    for key, query in azurerm_log_analytics_saved_search.hunting_queries : key => {
      id           = query.id
      name         = query.name
      display_name = query.display_name
      category     = query.category
      enabled      = true  # All deployed queries are enabled
    }
  }
}

output "hunting_query_ids" {
  description = "Map of hunting query keys to their Azure resource IDs"
  value = {
    for key, query in azurerm_log_analytics_saved_search.hunting_queries : key => query.id
  }
}

output "enabled_hunting_queries_count" {
  description = "Number of enabled hunting queries"
  value = length([
    for query in azurerm_log_analytics_saved_search.hunting_queries : query.id
  ])
}

output "hunting_query_names" {
  description = "List of deployed hunting query names"
  value = [
    for query in azurerm_log_analytics_saved_search.hunting_queries : query.display_name
  ]
}
