# Local values for processing and transforming content definitions
locals {
  # Read all YAML files from each content directory
  scheduled_rules_files    = fileset("${path.module}/content/scheduled-rules", "*.yaml")
  nrt_rules_files          = fileset("${path.module}/content/nrt-rules", "*.yaml")
  # DEPRECATED: fusion_rules_files = fileset("${path.module}/content/fusion-rules", "*.yaml")
  microsoft_rules_files    = fileset("${path.module}/content/microsoft-rules", "*.yaml")
  
  # Phase 2 content files
  playbooks_files       = fileset("${path.module}/content/playbooks", "*.yaml")
  hunting_queries_files = fileset("${path.module}/content/hunting-queries", "*.yaml")
  automation_rules_files = fileset("${path.module}/content/automation-rules", "*.yaml")
  
  # Phase 3 content files
  watchlists_files = fileset("${path.module}/content/watchlists", "*.csv")

  # Import content definitions from individual YAML files
  scheduled_rules_content = {
    for file in local.scheduled_rules_files :
    trimsuffix(file, ".yaml") => try(yamldecode(file("${path.module}/content/scheduled-rules/${file}")), {})
  }

  nrt_rules_content = {
    for file in local.nrt_rules_files :
    trimsuffix(file, ".yaml") => try(yamldecode(file("${path.module}/content/nrt-rules/${file}")), {})
  }

  # DEPRECATED: Fusion rules content processing removed
  # fusion_rules_content = {
  #   for file in local.fusion_rules_files :
  #   trimsuffix(file, ".yaml") => try(yamldecode(file("${path.module}/content/fusion-rules/${file}")), {})
  # }

  microsoft_rules_content = {
    for file in local.microsoft_rules_files :
    trimsuffix(file, ".yaml") => try(yamldecode(file("${path.module}/content/microsoft-rules/${file}")), {})
  }

  # Phase 2: Import content definitions from individual YAML files
  playbooks_content = {
    for file in local.playbooks_files :
    trimsuffix(file, ".yaml") => try(yamldecode(file("${path.module}/content/playbooks/${file}")), {})
  }

  automation_rules_content = {
    for file in local.automation_rules_files :
    trimsuffix(file, ".yaml") => try(yamldecode(file("${path.module}/content/automation-rules/${file}")), {})
  }

  hunting_queries_content = {
    for file in local.hunting_queries_files :
    trimsuffix(file, ".yaml") => try(yamldecode(file("${path.module}/content/hunting-queries/${file}")), {})
  }

  # Phase 3: Import watchlist definitions
  # For CSV watchlists, we need both metadata (.yaml) and data (.csv) files
  watchlists_metadata_files = fileset("${path.module}/content/watchlists", "*-metadata.yaml")
  
  # Import watchlist metadata from YAML files
  watchlists_metadata = {
    for file in local.watchlists_metadata_files :
    replace(trimsuffix(file, ".yaml"), "-metadata", "") => try(yamldecode(file("${path.module}/content/watchlists/${file}")), {})
  }
  
  # Process CSV files for watchlist data
  watchlists_csv_content = {
    for file in local.watchlists_files :
    trimsuffix(file, ".csv") => csvdecode(file("${path.module}/content/watchlists/${file}"))
  }

  # Process scheduled rules from content files - using individual rule configurations only
  scheduled_rules_raw = {
    for rule_key, rule_config in local.scheduled_rules_content : rule_key => {
      display_name                = rule_config.display_name
      description                 = lookup(rule_config, "description", "Managed by SentinelDaC Framework")
      severity                    = rule_config.severity
      enabled                     = rule_config.enabled
      query                       = rule_config.query
      query_frequency             = rule_config.query_frequency
      query_period                = rule_config.query_period
      trigger_operator            = lookup(rule_config, "trigger_operator", "GreaterThan")
      trigger_threshold           = lookup(rule_config, "trigger_threshold", 0)
      suppression_enabled         = lookup(rule_config, "suppression_enabled", false)
      suppression_duration        = lookup(rule_config, "suppression_duration", "PT1H")
      tactics                     = lookup(rule_config, "tactics", [])
      techniques                  = lookup(rule_config, "techniques", [])
      alert_rule_template_guid    = lookup(rule_config, "alert_rule_template_guid", null)
      alert_rule_template_version = lookup(rule_config, "alert_rule_template_version", null)
      custom_details              = lookup(rule_config, "custom_details", {})
      entity_mappings             = lookup(rule_config, "entity_mappings", [])
      incident_configuration      = lookup(rule_config, "incident_configuration", null)
      event_grouping              = lookup(rule_config, "event_grouping", { aggregation_method = "SingleAlert" })
      alert_details_override      = lookup(rule_config, "alert_details_override", null)
      tags                        = merge(var.deployment_tags, lookup(rule_config, "tags", {}))
    }
  }

  scheduled_rules = local.scheduled_rules_raw

  # Process NRT rules from content files - simplified configuration for near real-time rules
  nrt_rules_raw = {
    for rule_key, rule_config in local.nrt_rules_content : rule_key => {
      display_name                = rule_config.display_name
      description                 = lookup(rule_config, "description", "Managed by SentinelDaC Framework")
      severity                    = rule_config.severity
      enabled                     = rule_config.enabled
      query                       = rule_config.query
      suppression_enabled         = lookup(rule_config, "suppression_enabled", false)
      suppression_duration        = lookup(rule_config, "suppression_duration", "PT1H")
      tactics                     = lookup(rule_config, "tactics", [])
      techniques                  = lookup(rule_config, "techniques", [])
      alert_rule_template_guid    = lookup(rule_config, "alert_rule_template_guid", null)
      alert_rule_template_version = lookup(rule_config, "alert_rule_template_version", null)
      custom_details              = lookup(rule_config, "custom_details", {})
      entity_mappings             = lookup(rule_config, "entity_mappings", [])
      incident_configuration      = lookup(rule_config, "incident_configuration", null)
      event_grouping              = lookup(rule_config, "event_grouping", { aggregation_method = "SingleAlert" })
      alert_details_override      = lookup(rule_config, "alert_details_override", null)
      tags                        = merge(var.deployment_tags, lookup(rule_config, "tags", {}))
    }
  }

  nrt_rules = local.nrt_rules_raw

  # DEPRECATED: Fusion rules processing removed - being phased out in Defender portal migration
  # fusion_rules = local.fusion_rules_content

  # Process Microsoft rules from content files - pass through enabled status to module
  microsoft_rules = local.microsoft_rules_content

  # Phase 2: Process Phase 2 content from files
  # For resources with native enabled/disabled: pass all content, let modules handle state
  playbooks = local.playbooks_content
  
  # For resources without native enabled/disabled: filter out disabled content
  automation_rules = {
    for key, content in local.automation_rules_content :
    key => content
    if lookup(content, "enabled", true) == true
  }
  
  hunting_queries = {
    for key, content in local.hunting_queries_content :
    key => content
    if lookup(content, "enabled", true) == true
  }

  # Phase 3: Process Watchlists - combine metadata with CSV data
  watchlists = {
    for key, metadata in local.watchlists_metadata :
    key => merge(metadata, {
      items = lookup(local.watchlists_csv_content, key, [])
    })
    if lookup(metadata, "enabled", true) == true
  }
}
