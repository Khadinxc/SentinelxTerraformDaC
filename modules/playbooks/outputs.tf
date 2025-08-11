# Outputs for the playbooks module
output "playbook_details" {
  description = "Details of created playbooks"
  value = {
    for key, playbook in azurerm_logic_app_workflow.playbook : key => {
      id           = playbook.id
      name         = playbook.name
      enabled      = playbook.enabled
      playbook_type = playbook.tags.PlaybookType
      trigger_type  = playbook.tags.TriggerType
    }
  }
}

output "playbook_ids" {
  description = "Map of playbook keys to their Azure resource IDs" 
  value = {
    for key, playbook in azurerm_logic_app_workflow.playbook : key => playbook.id
  }
}

output "playbook_names" {
  description = "List of deployed playbook names"
  value = [
    for playbook in azurerm_logic_app_workflow.playbook : playbook.name
  ]
}

output "enabled_playbooks_count" {
  description = "Number of enabled playbooks"
  value = length([
    for playbook in azurerm_logic_app_workflow.playbook : playbook.id
    if playbook.enabled
  ])
}

output "sentinel_triggers" {
  description = "Details of Sentinel triggers"
  value = {
    for key, trigger in azurerm_logic_app_trigger_http_request.sentinel_trigger : key => {
      id         = trigger.id
      name       = trigger.name
      callback_url = trigger.callback_url
    }
  }
  sensitive = true  # URLs may contain sensitive information
}

output "notification_action_groups" {
  description = "Details of notification action groups"
  value = {
    for key, ag in azurerm_monitor_action_group.playbook_notifications : key => {
      id   = ag.id
      name = ag.name
    }
  }
}

# Script-based playbook outputs
output "script_playbook_details" {
  description = "Details of script-based playbooks"
  value = {
    for key, runbook in azurerm_automation_runbook.script_playbook : key => {
      id            = runbook.id
      name          = runbook.name
      runbook_type  = runbook.runbook_type
      script_type   = runbook.tags.ScriptType
      playbook_type = runbook.tags.PlaybookType
    }
  }
}

output "script_webhook_details" {
  description = "Details of script playbook webhooks"
  value = {
    for key, webhook in azurerm_automation_webhook.script_webhook : key => {
      id           = webhook.id
      name         = webhook.name
      uri          = webhook.uri
      runbook_name = webhook.runbook_name
    }
  }
  sensitive = true  # Webhook URIs contain sensitive information
}

output "all_playbook_references" {
  description = "Combined reference map for all playbooks (Logic Apps and Scripts)"
  value = merge(
    # Logic App playbooks
    {
      for key, playbook in azurerm_logic_app_workflow.playbook : key => {
        resource_id   = playbook.id
        name          = playbook.name
        type          = "LogicApp"
        trigger_url   = try(azurerm_logic_app_trigger_http_request.sentinel_trigger[key].callback_url, null)
        playbook_type = playbook.tags.PlaybookType
      }
    },
    # Script playbooks (webhook callers for Sentinel integration)
    {
      for key, webhook_caller in azurerm_logic_app_workflow.webhook_caller : key => {
        resource_id   = webhook_caller.id
        name          = webhook_caller.name
        type          = "Script"
        trigger_url   = azurerm_logic_app_trigger_http_request.webhook_caller_trigger[key].callback_url
        playbook_type = webhook_caller.tags.PlaybookType
        script_type   = webhook_caller.tags.ScriptType
        webhook_uri   = azurerm_automation_webhook.script_webhook[key].uri
      }
    }
  )
  sensitive = true
}
