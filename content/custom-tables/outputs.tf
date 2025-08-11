output "custom_table_ids" {
  description = "Map of custom table names to their resource IDs"
  value = {
    for name, table in azapi_resource.custom_tables : name => table.id
  }
}

output "custom_table_names" {
  description = "List of created custom table names"
  value = [
    for table in azapi_resource.custom_tables : table.name
  ]
}

output "deployment_summary" {
  description = "Summary of custom tables deployment"
  value = {
    total_tables_created = length(azapi_resource.custom_tables)
    table_names         = [for table in azapi_resource.custom_tables : table.name]
    deployment_timestamp = timestamp()
  }
}
