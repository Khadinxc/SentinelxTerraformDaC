# SentinelDaC Configuration
# Update these values to match your Azure environment

# Infrastructure Settings (matching your setup)
# NOTE: Replace with your actual Azure subscription ID, rg name, and law name.
subscription_id              = "[YOUR_AZURE_SUBSCRIPTION_ID]"
resource_group_name          = "[YOUR_RESOURCE_GROUP_NAME]"
log_analytics_workspace_name = "[YOUR_LOG_ANALYTICS_WORKSPACE_NAME]"

# Environment Configuration
environment = "dev"

# Deployment Tags
deployment_tags = {
  Environment = "dev"
  Project     = "SentinelDaC"
  ManagedBy   = "Terraform"
  Framework   = "Detection-as-Code"
  Version     = "v3.0"
  Owner       = "SecurityTeam"
  CostCenter  = "Security"
}

# Feature Toggles for Phase 1
enable_scheduled_rules     = true
enable_nrt_rules           = true
enable_microsoft_rules     = true

# Phase 2+ Features (updated scope)
enable_playbooks        = true   # Enable for Phase 2 development  
enable_hunting_queries  = true   # Enable for Phase 2 development
enable_automation_rules = true   # Enable for Phase 2+ development
enable_watchlists       = true   # Enable for Phase 3 development
enable_data_collection  = true   # Enable for data collection rules migration
enable_data_connectors  = true   # Enable for data connectors migration

# Automation Account for Script-based Playbooks
automation_account_name = "automation-account-dev-2"

# Rule Configuration
custom_rule_prefix = "Custom"

# Custom Tables Configuration (must be created before DCRs)
custom_tables = {
  # Table for security events DCR
  security_events = {
    name = "SecurityEvents_CL"
    description = "Custom table for security events ingested via DCR API"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "EventType", type = "string" },
      { name = "SourceIP", type = "string" },
      { name = "DestinationIP", type = "string" },
      { name = "Protocol", type = "string" },
      { name = "Action", type = "string" },
      { name = "Severity", type = "string" },
      { name = "Message", type = "string" }
    ]
    retention_days = 30
  }
  
  # Table for minimal logs (already exists but adding for completeness)
  minimal_logs = {
    name = "MinimalLogs_CL"
    description = "Custom table for minimal log events"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "Message", type = "string" }
    ]
    retention_days = 30
  }
  
  # ASIM Schema Tables for dedicated DCR ingestion
  asim_network_session = {
    name = "AsimNetworkSession_CL"
    description = "ASIM Network Session events for dedicated DCR ingestion"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "EventVendor", type = "string" },
      { name = "EventProduct", type = "string" },
      { name = "EventSchemaVersion", type = "string" },
      { name = "EventType", type = "string" },
      { name = "SrcIpAddr", type = "string" },
      { name = "DstIpAddr", type = "string" },
      { name = "SrcPortNumber", type = "int" },
      { name = "DstPortNumber", type = "int" },
      { name = "IpProtocol", type = "string" },
      { name = "NetworkDirection", type = "string" },
      { name = "NetworkDuration", type = "int" },
      { name = "NetworkBytes", type = "long" },
      { name = "NetworkPackets", type = "int" },
      { name = "EventResult", type = "string" },
      { name = "EventSeverity", type = "string" }
    ]
    retention_days = 90
  }
  
  asim_dns_activity = {
    name = "AsimDnsActivity_CL"
    description = "ASIM DNS Activity events for dedicated DCR ingestion"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "EventVendor", type = "string" },
      { name = "EventProduct", type = "string" },
      { name = "EventSchemaVersion", type = "string" },
      { name = "EventType", type = "string" },
      { name = "SrcIpAddr", type = "string" },
      { name = "DnsQuery", type = "string" },
      { name = "DnsQueryType", type = "int" },
      { name = "DnsQueryTypeName", type = "string" },
      { name = "DnsResponseCode", type = "int" },
      { name = "DnsResponseCodeName", type = "string" },
      { name = "DnsResponseName", type = "string" },
      { name = "EventResult", type = "string" },
      { name = "EventSeverity", type = "string" }
    ]
    retention_days = 90
  }
  
  asim_authentication = {
    name = "AsimAuthentication_CL"
    description = "ASIM Authentication events for dedicated DCR ingestion"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "EventVendor", type = "string" },
      { name = "EventProduct", type = "string" },
      { name = "EventSchemaVersion", type = "string" },
      { name = "EventType", type = "string" },
      { name = "ActorUserId", type = "string" },
      { name = "ActorUsername", type = "string" },
      { name = "TargetUserId", type = "string" },
      { name = "TargetUsername", type = "string" },
      { name = "SrcIpAddr", type = "string" },
      { name = "LogonMethod", type = "string" },
      { name = "LogonProtocol", type = "string" },
      { name = "EventResult", type = "string" },
      { name = "EventResultDetails", type = "string" },
      { name = "EventSeverity", type = "string" }
    ]
    retention_days = 90
  }
  
  asim_process_event = {
    name = "AsimProcessEvent_CL"
    description = "ASIM Process Event logs for dedicated DCR ingestion"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "EventVendor", type = "string" },
      { name = "EventProduct", type = "string" },
      { name = "EventSchemaVersion", type = "string" },
      { name = "EventType", type = "string" },
      { name = "ActorUsername", type = "string" },
      { name = "DvcHostname", type = "string" },
      { name = "DvcOs", type = "string" },
      { name = "ProcessName", type = "string" },
      { name = "ProcessCommandLine", type = "string" },
      { name = "ProcessId", type = "string" },
      { name = "ParentProcessName", type = "string" },
      { name = "ParentProcessId", type = "string" },
      { name = "EventResult", type = "string" },
      { name = "EventSeverity", type = "string" }
    ]
    retention_days = 90
  }
  
  asim_file_event = {
    name = "AsimFileEvent_CL"
    description = "ASIM File Event logs for dedicated DCR ingestion"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "EventVendor", type = "string" },
      { name = "EventProduct", type = "string" },
      { name = "EventSchemaVersion", type = "string" },
      { name = "EventType", type = "string" },
      { name = "ActorUsername", type = "string" },
      { name = "DvcHostname", type = "string" },
      { name = "DvcOs", type = "string" },
      { name = "TargetFilePath", type = "string" },
      { name = "TargetFileName", type = "string" },
      { name = "TargetFileExtension", type = "string" },
      { name = "SrcFilePath", type = "string" },
      { name = "EventResult", type = "string" },
      { name = "EventSeverity", type = "string" }
    ]
    retention_days = 90
  }
  
  asim_registry_event = {
    name = "AsimRegistryEvent_CL"
    description = "ASIM Registry Event logs for dedicated DCR ingestion"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "EventVendor", type = "string" },
      { name = "EventProduct", type = "string" },
      { name = "EventSchemaVersion", type = "string" },
      { name = "EventType", type = "string" },
      { name = "ActorUsername", type = "string" },
      { name = "DvcHostname", type = "string" },
      { name = "DvcOs", type = "string" },
      { name = "RegistryKey", type = "string" },
      { name = "RegistryValue", type = "string" },
      { name = "RegistryValueType", type = "string" },
      { name = "RegistryValueData", type = "string" },
      { name = "EventResult", type = "string" },
      { name = "EventSeverity", type = "string" }
    ]
    retention_days = 90
  }
  
  asim_web_session = {
    name = "AsimWebSession_CL"
    description = "ASIM Web Session logs for dedicated DCR ingestion"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "EventVendor", type = "string" },
      { name = "EventProduct", type = "string" },
      { name = "EventSchemaVersion", type = "string" },
      { name = "EventType", type = "string" },
      { name = "SrcIpAddr", type = "string" },
      { name = "DstIpAddr", type = "string" },
      { name = "Url", type = "string" },
      { name = "HttpMethod", type = "string" },
      { name = "HttpStatusCode", type = "string" },
      { name = "HttpUserAgent", type = "string" },
      { name = "HttpReferrer", type = "string" },
      { name = "NetworkBytes", type = "long" },
      { name = "EventResult", type = "string" },
      { name = "EventSeverity", type = "string" }
    ]
    retention_days = 90
  }
  
  asim_audit_event = {
    name = "AsimAuditEvent_CL"
    description = "ASIM Audit Event logs for dedicated DCR ingestion"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "EventVendor", type = "string" },
      { name = "EventProduct", type = "string" },
      { name = "EventSchemaVersion", type = "string" },
      { name = "EventType", type = "string" },
      { name = "ActorUsername", type = "string" },
      { name = "ActorUserId", type = "string" },
      { name = "SrcIpAddr", type = "string" },
      { name = "Operation", type = "string" },
      { name = "Object", type = "string" },
      { name = "ObjectType", type = "string" },
      { name = "EventResult", type = "string" },
      { name = "EventResultDetails", type = "string" },
      { name = "EventSeverity", type = "string" }
    ]
    retention_days = 90
  }
}

# Data Collection Endpoints Configuration (API ingestion like Splunk HEC)
dce_configs = {
  # API endpoint for custom applications
  api_ingestion = {
    name                          = "dce-api-ingestion-dev"
    description                   = "API endpoint for custom application data ingestion"
    public_network_access_enabled = true
  }
  
  # Private endpoint for secure internal systems
  private_ingestion = {
    name                          = "dce-private-ingestion-dev"
    description                   = "Private endpoint for internal system data ingestion"
    public_network_access_enabled = false
  }
}

# Data Collection Rules Configuration
dcr_configs = {
  ## Linux syslog
  linux_syslog = {
    name         = "dcr-syslog-linux-dev"
    data_type    = "syslog"
    facilities   = ["auth", "authpriv", "cron", "daemon", "kern", "syslog"]
    log_levels   = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    destinations = ["primary"]
  }
  
  ## Windows Events
  windows_security = {
    name         = "dcr-windows-security-dev"
    data_type    = "windows_event_log"
    facilities   = ["Security", "System"]
    log_levels   = ["Information", "Warning", "Error", "Critical"]
    destinations = ["primary"]
  }
  
  # Security Events API logs DCR - applying lessons learned from Azure CLI success
  api_logs_security = {
    name         = "dcr-api-security-events-dev"
    data_type    = "custom"
    facilities   = []
    log_levels   = []
    destinations = ["primary"]
    data_collection_endpoint_key = "api_ingestion"  # Use the existing DCE
    
    # Stream declarations based on successful Azure CLI pattern
    stream_declarations = {
      "Custom-SecurityEvents" = {
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "EventType", type = "string" },
          { name = "SourceIP", type = "string" },
          { name = "DestinationIP", type = "string" },
          { name = "Protocol", type = "string" },
          { name = "Action", type = "string" },
          { name = "Severity", type = "string" },
          { name = "Message", type = "string" }
        ]
      }
    }
    output_stream = "Custom-SecurityEvents_CL"  # Following exact pattern from working DCR
    
    # Simple transformation that worked in Azure CLI
    transform_kql = "source | extend TimeGenerated = now()"
  }
  
  ## ASIM Schema DCRs - One DCR per schema following Microsoft best practices
  ## Each DCR gets dedicated 2GB/min and 12K requests/min limits for optimal performance
  
  # ASIM Network Session DCR
  asim_network_session = {
    name         = "dcr-asim-networksession-dev"
    data_type    = "custom"
    facilities   = []
    log_levels   = []
    destinations = ["primary"]
    data_collection_endpoint_key = "api_ingestion"
    
    stream_declarations = {
      "Custom-AsimNetworkSession" = {
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "EventVendor", type = "string" },
          { name = "EventProduct", type = "string" },
          { name = "EventSchemaVersion", type = "string" },
          { name = "EventType", type = "string" },
          { name = "SrcIpAddr", type = "string" },
          { name = "DstIpAddr", type = "string" },
          { name = "SrcPortNumber", type = "int" },
          { name = "DstPortNumber", type = "int" },
          { name = "IpProtocol", type = "string" },
          { name = "NetworkDirection", type = "string" },
          { name = "NetworkDuration", type = "int" },
          { name = "NetworkBytes", type = "long" },
          { name = "NetworkPackets", type = "int" },
          { name = "EventResult", type = "string" },
          { name = "EventSeverity", type = "string" }
        ]
      }
    }
    output_stream = "Custom-AsimNetworkSession_CL"
    transform_kql = "source"
  }
  
  # ASIM DNS Activity DCR
  asim_dns_activity = {
    name         = "dcr-asim-dnsactivity-dev"
    data_type    = "custom"
    facilities   = []
    log_levels   = []
    destinations = ["primary"]
    data_collection_endpoint_key = "api_ingestion"
    
    stream_declarations = {
      "Custom-AsimDnsActivity" = {
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "EventVendor", type = "string" },
          { name = "EventProduct", type = "string" },
          { name = "EventSchemaVersion", type = "string" },
          { name = "EventType", type = "string" },
          { name = "SrcIpAddr", type = "string" },
          { name = "DnsQuery", type = "string" },
          { name = "DnsQueryType", type = "int" },
          { name = "DnsQueryTypeName", type = "string" },
          { name = "DnsResponseCode", type = "int" },
          { name = "DnsResponseCodeName", type = "string" },
          { name = "DnsResponseName", type = "string" },
          { name = "EventResult", type = "string" },
          { name = "EventSeverity", type = "string" }
        ]
      }
    }
    output_stream = "Custom-AsimDnsActivity_CL"
    transform_kql = "source"
  }
  
  # ASIM Authentication DCR
  asim_authentication = {
    name         = "dcr-asim-authentication-dev"
    data_type    = "custom"
    facilities   = []
    log_levels   = []
    destinations = ["primary"]
    data_collection_endpoint_key = "api_ingestion"
    
    stream_declarations = {
      "Custom-AsimAuthentication" = {
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "EventVendor", type = "string" },
          { name = "EventProduct", type = "string" },
          { name = "EventSchemaVersion", type = "string" },
          { name = "EventType", type = "string" },
          { name = "ActorUserId", type = "string" },
          { name = "ActorUsername", type = "string" },
          { name = "TargetUserId", type = "string" },
          { name = "TargetUsername", type = "string" },
          { name = "SrcIpAddr", type = "string" },
          { name = "LogonMethod", type = "string" },
          { name = "LogonProtocol", type = "string" },
          { name = "EventResult", type = "string" },
          { name = "EventResultDetails", type = "string" },
          { name = "EventSeverity", type = "string" }
        ]
      }
    }
    output_stream = "Custom-AsimAuthentication_CL"
    transform_kql = "source"
  }
  
  # ASIM Process Event DCR
  asim_process_event = {
    name         = "dcr-asim-processevent-dev"
    data_type    = "custom"
    facilities   = []
    log_levels   = []
    destinations = ["primary"]
    data_collection_endpoint_key = "api_ingestion"
    
    stream_declarations = {
      "Custom-AsimProcessEvent" = {
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "EventVendor", type = "string" },
          { name = "EventProduct", type = "string" },
          { name = "EventSchemaVersion", type = "string" },
          { name = "EventType", type = "string" },
          { name = "ActorUsername", type = "string" },
          { name = "DvcHostname", type = "string" },
          { name = "DvcOs", type = "string" },
          { name = "ProcessName", type = "string" },
          { name = "ProcessCommandLine", type = "string" },
          { name = "ProcessId", type = "string" },
          { name = "ParentProcessName", type = "string" },
          { name = "ParentProcessId", type = "string" },
          { name = "EventResult", type = "string" },
          { name = "EventSeverity", type = "string" }
        ]
      }
    }
    output_stream = "Custom-AsimProcessEvent_CL"
    transform_kql = "source"
  }
  
  # ASIM File Event DCR
  asim_file_event = {
    name         = "dcr-asim-fileevent-dev"
    data_type    = "custom"
    facilities   = []
    log_levels   = []
    destinations = ["primary"]
    data_collection_endpoint_key = "api_ingestion"
    
    stream_declarations = {
      "Custom-AsimFileEvent" = {
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "EventVendor", type = "string" },
          { name = "EventProduct", type = "string" },
          { name = "EventSchemaVersion", type = "string" },
          { name = "EventType", type = "string" },
          { name = "ActorUsername", type = "string" },
          { name = "DvcHostname", type = "string" },
          { name = "DvcOs", type = "string" },
          { name = "TargetFilePath", type = "string" },
          { name = "TargetFileName", type = "string" },
          { name = "TargetFileExtension", type = "string" },
          { name = "SrcFilePath", type = "string" },
          { name = "EventResult", type = "string" },
          { name = "EventSeverity", type = "string" }
        ]
      }
    }
    output_stream = "Custom-AsimFileEvent_CL"
    transform_kql = "source"
  }
  
  # ASIM Registry Event DCR
  asim_registry_event = {
    name         = "dcr-asim-registryevent-dev"
    data_type    = "custom"
    facilities   = []
    log_levels   = []
    destinations = ["primary"]
    data_collection_endpoint_key = "api_ingestion"
    
    stream_declarations = {
      "Custom-AsimRegistryEvent" = {
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "EventVendor", type = "string" },
          { name = "EventProduct", type = "string" },
          { name = "EventSchemaVersion", type = "string" },
          { name = "EventType", type = "string" },
          { name = "ActorUsername", type = "string" },
          { name = "DvcHostname", type = "string" },
          { name = "DvcOs", type = "string" },
          { name = "RegistryKey", type = "string" },
          { name = "RegistryValue", type = "string" },
          { name = "RegistryValueType", type = "string" },
          { name = "RegistryValueData", type = "string" },
          { name = "EventResult", type = "string" },
          { name = "EventSeverity", type = "string" }
        ]
      }
    }
    output_stream = "Custom-AsimRegistryEvent_CL"
    transform_kql = "source"
  }
  
  # ASIM Web Session DCR
  asim_web_session = {
    name         = "dcr-asim-websession-dev"
    data_type    = "custom"
    facilities   = []
    log_levels   = []
    destinations = ["primary"]
    data_collection_endpoint_key = "api_ingestion"
    
    stream_declarations = {
      "Custom-AsimWebSession" = {
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "EventVendor", type = "string" },
          { name = "EventProduct", type = "string" },
          { name = "EventSchemaVersion", type = "string" },
          { name = "EventType", type = "string" },
          { name = "SrcIpAddr", type = "string" },
          { name = "DstIpAddr", type = "string" },
          { name = "Url", type = "string" },
          { name = "HttpMethod", type = "string" },
          { name = "HttpStatusCode", type = "string" },
          { name = "HttpUserAgent", type = "string" },
          { name = "HttpReferrer", type = "string" },
          { name = "NetworkBytes", type = "long" },
          { name = "EventResult", type = "string" },
          { name = "EventSeverity", type = "string" }
        ]
      }
    }
    output_stream = "Custom-AsimWebSession_CL"
    transform_kql = "source"
  }
  
  # ASIM Audit Event DCR
  asim_audit_event = {
    name         = "dcr-asim-auditevent-dev"
    data_type    = "custom"
    facilities   = []
    log_levels   = []
    destinations = ["primary"]
    data_collection_endpoint_key = "api_ingestion"
    
    stream_declarations = {
      "Custom-AsimAuditEvent" = {
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "EventVendor", type = "string" },
          { name = "EventProduct", type = "string" },
          { name = "EventSchemaVersion", type = "string" },
          { name = "EventType", type = "string" },
          { name = "ActorUsername", type = "string" },
          { name = "ActorUserId", type = "string" },
          { name = "SrcIpAddr", type = "string" },
          { name = "Operation", type = "string" },
          { name = "Object", type = "string" },
          { name = "ObjectType", type = "string" },
          { name = "EventResult", type = "string" },
          { name = "EventResultDetails", type = "string" },
          { name = "EventSeverity", type = "string" }
        ]
      }
    }
    output_stream = "Custom-AsimAuditEvent_CL"
    transform_kql = "source"
  }
}

# Data Connectors Configuration
connector_configs = {
  ms_threat_intelligence = {
    name    = "microsoft-threat-intelligence-dev"
    type    = "microsoft_threat_intelligence"
    date    = "2025-07-30T00:00:00Z"
    enabled = true
  }
}
