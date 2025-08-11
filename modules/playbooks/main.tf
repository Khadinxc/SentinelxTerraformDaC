# Playbooks Module
# This module creates Logic App playbooks and Automation Runbooks for Microsoft Sentinel

# Data source for existing Azure Automation Account
data "azurerm_automation_account" "sentinel_automation" {
  count               = var.automation_account_name != "" ? 1 : 0
  name                = var.automation_account_name
  resource_group_name = var.resource_group_name
}

# Terraform configuration for Logic App playbooks
resource "azurerm_logic_app_workflow" "playbook" {
  for_each = {
    for k, v in var.playbooks : k => v
    if v.enabled && lookup(v, "execution_type", "LogicApp") == "LogicApp"
  }

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Enable or disable the logic app based on the enabled flag
  enabled = each.value.enabled

  # Tags for metadata and categorization
  tags = merge(
    var.common_tags,
    {
      PlaybookType    = each.value.playbook_type
      Severity        = each.value.severity
      TriggerType     = each.value.trigger_type
      Description     = each.value.description
      Author          = lookup(each.value, "author", "SentinelDaC")
      Version         = lookup(each.value, "version", "1.0")
      LastUpdated     = formatdate("YYYY-MM-DD", timestamp())
    },
    lookup(each.value, "tags", {})
  )

  lifecycle {
    ignore_changes = [
      tags["LastUpdated"]
    ]
  }
}

# Logic App trigger for Sentinel incidents (if trigger_type is "Sentinel")
resource "azurerm_logic_app_trigger_http_request" "sentinel_trigger" {
  for_each = {
    for k, v in var.playbooks : k => v
    if v.enabled && v.trigger_type == "Sentinel" && lookup(v, "execution_type", "LogicApp") == "LogicApp"
  }

  name         = "When_a_response_to_an_Azure_Sentinel_alert_is_triggered"
  logic_app_id = azurerm_logic_app_workflow.playbook[each.key].id

  schema = jsonencode({
    type = "object"
    properties = {
      WorkspaceSubscriptionId = {
        type = "string"
      }
      WorkspaceId = {
        type = "string"
      }
      WorkspaceResourceGroup = {
        type = "string"
      }
      AlertRuleName = {
        type = "string"
      }
      AlertRuleId = {
        type = "string"
      }
      IncidentId = {
        type = "string"
      }
      IncidentTitle = {
        type = "string"
      }
      IncidentDescription = {
        type = "string"
      }
      IncidentSeverity = {
        type = "string"
      }
      IncidentStatus = {
        type = "string"
      }
      Entities = {
        type = "array"
      }
    }
  })
}

# Logic App HTTP trigger for custom integrations
resource "azurerm_logic_app_trigger_http_request" "http_trigger" {
  for_each = {
    for k, v in var.playbooks : k => v
    if v.enabled && v.trigger_type == "HTTP" && lookup(v, "execution_type", "LogicApp") == "LogicApp"
  }

  name         = "When_HTTP_request_is_received"
  logic_app_id = azurerm_logic_app_workflow.playbook[each.key].id

  schema = jsonencode({
    type = "object"
    properties = lookup(each.value, "http_schema", {
      message = {
        type = "string"
      }
    })
  })
}

# Logic App schedule trigger for automated playbooks
resource "azurerm_logic_app_trigger_recurrence" "schedule_trigger" {
  for_each = {
    for k, v in var.playbooks : k => v
    if v.enabled && v.trigger_type == "Schedule" && lookup(v, "execution_type", "LogicApp") == "LogicApp"
  }

  name         = "Recurrence"
  logic_app_id = azurerm_logic_app_workflow.playbook[each.key].id
  frequency    = lookup(each.value, "schedule_frequency", "Day")
  interval     = lookup(each.value, "schedule_interval", 1)

  dynamic "schedule" {
    for_each = lookup(each.value, "schedule_time", null) != null ? [1] : []
    content {
      at_these_hours   = [split(":", each.value.schedule_time)[0]]
      at_these_minutes = [split(":", each.value.schedule_time)[1]]
    }
  }
}

# Action groups for notification playbooks
resource "azurerm_monitor_action_group" "playbook_notifications" {
  for_each = {
    for k, v in var.playbooks : k => v
    if v.enabled && v.playbook_type == "Notification" && lookup(v, "execution_type", "LogicApp") == "LogicApp"
  }

  name                = "${each.value.name}-notifications"
  resource_group_name = var.resource_group_name
  short_name          = substr(replace(each.value.name, "-", ""), 0, 12)

  dynamic "logic_app_receiver" {
    for_each = [1]
    content {
      name                    = each.value.name
      resource_id            = azurerm_logic_app_workflow.playbook[each.key].id
      callback_url           = "https://prod-00.eastus.logic.azure.com:443/workflows/${azurerm_logic_app_workflow.playbook[each.key].id}/triggers/manual/paths/invoke"
      use_common_alert_schema = true
    }
  }

  tags = var.common_tags
}

# ============================================================================
# WEBHOOK CALLER LOGIC APPS (for Script-based Playbooks)
# ============================================================================

# Create webhook caller Logic Apps for script-based playbooks
# This is needed because Sentinel automation rules only support Logic Apps
resource "azurerm_logic_app_workflow" "webhook_caller" {
  for_each = {
    for key, playbook_config in var.playbooks : key => playbook_config
    if playbook_config.enabled && lookup(playbook_config, "execution_type", "LogicApp") == "Script"
  }

  name                = "${each.key}-webhook-caller"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  enabled = true

  tags = merge(var.common_tags, {
    PlaybookType   = each.value.playbook_type
    TriggerType    = each.value.trigger_type
    ExecutionType  = "WebhookCaller"
    ScriptType     = each.value.script_type
    Purpose        = "Script Webhook Caller"
  }, lookup(each.value, "tags", {}))
}

# Create Sentinel triggers for webhook caller Logic Apps
resource "azurerm_logic_app_trigger_http_request" "webhook_caller_trigger" {
  for_each = azurerm_logic_app_workflow.webhook_caller

  name         = "When_a_response_to_an_Azure_Sentinel_alert_is_triggered"
  logic_app_id = each.value.id
  
  schema = jsonencode({
    type = "object"
    properties = {
      object = {
        type = "object"
        properties = {
          properties = {
            type = "object"
            properties = {
              incidentNumber = { type = "string" }
              title = { type = "string" }
              severity = { type = "string" }
            }
          }
        }
      }
      ExtendedProperties = {
        type = "object"
        properties = {
          MaliciousIP = { type = "string" }
          SuspiciousIP = { type = "string" }
        }
      }
    }
  })
}

# Create HTTP actions to call the actual script webhooks
resource "azurerm_logic_app_action_http" "webhook_call" {
  for_each = azurerm_logic_app_workflow.webhook_caller

  name         = "Call_Script_Webhook"
  logic_app_id = each.value.id
  method       = "POST"
  uri          = azurerm_automation_webhook.script_webhook[each.key].uri
  
  headers = {
    "Content-Type" = "application/json"
  }
  
  # Pass the incident data to the webhook
  body = jsonencode({
    IncidentId = "@{triggerBody()?['object']?['properties']?['incidentNumber']}"
    IncidentTitle = "@{triggerBody()?['object']?['properties']?['title']}"
    Severity = "@{triggerBody()?['object']?['properties']?['severity']}"
    MaliciousIP = "@{triggerBody()?['ExtendedProperties']?['MaliciousIP']}"
    SuspiciousIP = "@{triggerBody()?['ExtendedProperties']?['SuspiciousIP']}"
  })

  depends_on = [
    azurerm_logic_app_trigger_http_request.webhook_caller_trigger,
    azurerm_automation_webhook.script_webhook
  ]
}

# ============================================================================
# AUTOMATION RUNBOOKS (Script-based Playbooks)
# ============================================================================

# Automation Runbooks for script-based playbooks
resource "azurerm_automation_runbook" "script_playbook" {
  for_each = {
    for k, v in var.playbooks : k => v
    if v.enabled && lookup(v, "execution_type", "LogicApp") == "Script" && var.automation_account_name != ""
  }

  name                    = each.value.name
  automation_account_name = var.automation_account_name
  resource_group_name     = var.resource_group_name
  location               = var.location
  runbook_type           = each.value.script_type == "Python" ? "Python3" : each.value.script_type
  log_verbose            = true
  log_progress           = true
  description            = "${each.value.description} - ${each.value.playbook_type} playbook"

  content = each.value.script_content

  tags = merge(
    {
      Environment     = lookup(var.common_tags, "Environment", "dev")
      Project         = lookup(var.common_tags, "Project", "SentinelDaC") 
      ManagedBy       = "Terraform"
      PlaybookType    = each.value.playbook_type
      ExecutionType   = "Script"
      ScriptType      = each.value.script_type
    }
  )

  lifecycle {
    ignore_changes = [
      tags["LastUpdated"]
    ]
  }
}

# Webhooks for Sentinel to trigger script playbooks
resource "azurerm_automation_webhook" "script_webhook" {
  for_each = {
    for k, v in var.playbooks : k => v
    if v.enabled && lookup(v, "execution_type", "LogicApp") == "Script" && 
       v.trigger_type == "Sentinel" && var.automation_account_name != ""
  }

  name                    = "${each.value.name}-webhook"
  automation_account_name = var.automation_account_name
  resource_group_name     = var.resource_group_name
  expiry_time            = "2026-08-05T10:06:12+00:00" # 1 year from now
  enabled                = true
  runbook_name           = azurerm_automation_runbook.script_playbook[each.key].name

  parameters = each.value.parameters
}
