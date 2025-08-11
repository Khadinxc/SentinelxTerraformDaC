# Azure Data Collection Endpoint Event Poster for ASIM Tables
# Posts JSON events to Azure Monitor Data Collection Endpoints (DCE) for ASIM normalization
# Compatible with ASIM (Advanced Security Information Model) schemas

# NOTE: Create GitHub secrets in your repository for the following:
# - AZURE_TENANT_ID: Your Azure AD tenant ID
# - AZURE_CLIENT_ID: Your Azure AD application client ID  
# - AZURE_CLIENT_SECRET: Your Azure AD application client secret
param(
  [Parameter(Mandatory=$false)] [string]$TenantId = $env:AZURE_TENANT_ID,
  [Parameter(Mandatory=$false)] [string]$ClientId = $env:AZURE_CLIENT_ID,
  [Parameter(Mandatory=$true)] [string]$ClientSecret,
  [Parameter(Mandatory=$false)] [string]$DceBaseUrl = "https://dce-api-ingestion-dev-1tty.australiaeast-1.ingest.monitor.azure.com",
  [Parameter(Mandatory=$false)] [string]$DcrImmutableId = "dcr-cdb40ceabb6242d5b7d412b04961c24e",
  [Parameter(Mandatory=$true)] [ValidateSet("NetworkSession", "DnsActivity", "Authentication", "ProcessEvent", "FileEvent", "RegistryEvent", "WebSession", "AuditEvent")] [string]$AsimSchema,
  [string]$StreamName,  # Will be auto-generated based on AsimSchema if not provided
  [string]$InputJsonPath,
  [Object[]]$Events,
  [switch]$Gzip,
  [switch]$ShowBody,
  [switch]$ValidateOnly  # Only validate field mappings without sending data
)

# =====================================================================================
# ASIM SCHEMA CONFIGURATION
# =====================================================================================
# ASIM (Advanced Security Information Model) provides standardized schemas for security data
# Reference: https://learn.microsoft.com/en-us/azure/sentinel/normalization-about-schemas
#
# SUPPORTED ASIM SCHEMAS:
# - NetworkSession: Network connections, flows, sessions
# - DnsActivity: DNS queries and responses  
# - Authentication: Authentication and authorization events
# - ProcessEvent: Process creation, termination, and modification
# - FileEvent: File system operations (create, read, write, delete)
# - RegistryEvent: Windows Registry operations
# - WebSession: Web/HTTP requests and responses
# - AuditEvent: Audit and compliance events
#
# USAGE EXAMPLES:
# .\post-events-to-dce-asim.ps1 -AsimSchema "NetworkSession" -InputJsonPath "network-logs.json" -ClientSecret "xxx"
# .\post-events-to-dce-asim.ps1 -AsimSchema "DnsActivity" -Events $dnsEvents -ClientSecret "xxx"
# .\post-events-to-dce-asim.ps1 -AsimSchema "Authentication" -InputJsonPath "auth-logs.json" -ValidateOnly
# =====================================================================================

$ErrorActionPreference = "Stop"

# Auto-generate StreamName based on ASIM schema if not provided
if (-not $StreamName) {
  $StreamName = "Custom-Asim$AsimSchema"
}

function Send-DataWithRetry {
  param(
    [string]$Uri,
    [hashtable]$Headers,
    [string]$Body,
    [byte[]]$CompressedBody = $null,
    [int]$MaxRetries = 5,
    [switch]$ShowRetryDetails
  )
  
  $retryCount = 0
  $baseBackoffSeconds = 1
  $maxBackoffSeconds = 300  # 5 minutes max
  
  do {
    try {
      # Send request with appropriate body format
      if ($CompressedBody) {
        $response = Invoke-WebRequest -Method Post -Uri $Uri -Headers $Headers -Body $CompressedBody -UseBasicParsing
      } else {
        $response = Invoke-WebRequest -Method Post -Uri $Uri -Headers $Headers -Body $Body -UseBasicParsing
      }
      
      # Success - check status codes
      if ($response.StatusCode -in 200, 202, 204) {
        if ($retryCount -gt 0) {
          Write-Host "✅ Success after $retryCount retries: HTTP $($response.StatusCode)" -ForegroundColor Green
        }
        return @{ Success = $true; Response = $response }
      } else {
        Write-Warning "⚠️ Unexpected status code: HTTP $($response.StatusCode)"
        return @{ Success = $false; Response = $response; Error = "Unexpected status code" }
      }
    }
    catch {
      $statusCode = $null
      $retryAfterSeconds = $null
      
      # Extract status code and retry-after header
      if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.Value__
        $retryAfterHeader = $_.Exception.Response.Headers["Retry-After"]
        if ($retryAfterHeader) {
          $retryAfterSeconds = [int]$retryAfterHeader
        }
      }
      
      # Handle specific error codes
      switch ($statusCode) {
        429 {
          # Rate limiting - this is recoverable
          $waitSeconds = if ($retryAfterSeconds) { $retryAfterSeconds } else { [Math]::Min($baseBackoffSeconds * [Math]::Pow(2, $retryCount), $maxBackoffSeconds) }
          
          if ($ShowRetryDetails) {
            Write-Warning "⚠️ Rate limited (HTTP 429). Attempt $($retryCount + 1)/$MaxRetries. Waiting $waitSeconds seconds..."
          }
          
          Start-Sleep -Seconds $waitSeconds
          $retryCount++
        }
        413 {
          # Payload too large - not recoverable with retry
          Write-Error "❌ Payload too large (HTTP 413). Reduce batch size and try again."
          return @{ Success = $false; Error = "Payload too large"; StatusCode = 413 }
        }
        401 {
          # Authentication failed - not recoverable with retry
          Write-Error "❌ Authentication failed (HTTP 401). Check credentials."
          return @{ Success = $false; Error = "Authentication failed"; StatusCode = 401 }
        }
        403 {
          # Forbidden - not recoverable with retry  
          Write-Error "❌ Access forbidden (HTTP 403). Check permissions."
          return @{ Success = $false; Error = "Access forbidden"; StatusCode = 403 }
        }
        default {
          # Other errors - retry up to limit
          if ($retryCount -lt $MaxRetries) {
            $waitSeconds = [Math]::Min($baseBackoffSeconds * [Math]::Pow(2, $retryCount), $maxBackoffSeconds)
            
            if ($ShowRetryDetails) {
              Write-Warning "⚠️ HTTP $statusCode error. Attempt $($retryCount + 1)/$MaxRetries. Waiting $waitSeconds seconds..."
              Write-Warning "Error: $($_.Exception.Message)"
              
              # Try to get response body for 400 errors
              if ($statusCode -eq 400 -and $_.Exception.Response) {
                try {
                  $responseStream = $_.Exception.Response.GetResponseStream()
                  $reader = New-Object System.IO.StreamReader($responseStream)
                  $responseBody = $reader.ReadToEnd()
                  Write-Warning "Response Body: $responseBody"
                  $reader.Close()
                  $responseStream.Close()
                } catch {
                  Write-Warning "Could not read response body: $($_.Exception.Message)"
                }
              }
            }
            
            Start-Sleep -Seconds $waitSeconds
            $retryCount++
          } else {
            # Max retries exceeded
            Write-Error "❌ CRITICAL: Max retries ($MaxRetries) exceeded. DATA WILL BE LOST!"
            Write-Error "Last error: $($_.Exception.Message)"
            return @{ Success = $false; Error = $_.Exception.Message; MaxRetriesExceeded = $true }
          }
        }
      }
    }
  } while ($retryCount -lt $MaxRetries)
  
  # If we reach here, all retries were exhausted
  Write-Error "❌ CRITICAL: All $MaxRetries retry attempts failed. DATA WILL BE LOST!"
  return @{ Success = $false; Error = "Max retries exceeded"; MaxRetriesExceeded = $true }
}

function Get-OAuthToken {
  param(
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret
  )
  $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
  $body = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://monitor.azure.com/.default"
  }
  $resp = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body -ContentType "application/x-www-form-urlencoded"
  return $resp.access_token
}

function Get-AsimFieldMapping {
  param([string]$Schema)
  
  # =====================================================================================
  # ASIM FIELD MAPPING CONFIGURATIONS
  # =====================================================================================
  # Each ASIM schema has specific required and optional fields
  # Reference: https://learn.microsoft.com/en-us/azure/sentinel/normalization-about-schemas
  # =====================================================================================
  
  switch ($Schema) {
    "NetworkSession" {
      return @{
        Description = "Network connections, sessions, and flows"
        RequiredFields = @("TimeGenerated", "EventType", "EventResult")
        MappingFunction = "Resolve-AsimNetworkSession"
        SampleData = @{
          timestamp = "2024-01-01T12:00:00Z"
          src_ip = "192.168.1.100"
          dst_ip = "203.0.113.45"
          src_port = 45123
          dst_port = 443
          protocol = "TCP"
          action = "Allow"
          bytes_sent = 1024
          bytes_received = 2048
        }
      }
    }
    "DnsActivity" {
      return @{
        Description = "DNS queries and responses"
        RequiredFields = @("TimeGenerated", "EventType", "DvcAction")
        MappingFunction = "Resolve-AsimDnsActivity"
        SampleData = @{
          timestamp = "2024-01-01T12:00:00Z"
          query = "example.com"
          query_type = "A"
          response_code = "NOERROR"
          src_ip = "192.168.1.100"
          dns_server = "8.8.8.8"
          answer = "93.184.216.34"
        }
      }
    }
    "Authentication" {
      return @{
        Description = "Authentication and authorization events"
        RequiredFields = @("TimeGenerated", "EventType", "EventResult")
        MappingFunction = "Resolve-AsimAuthentication"
        SampleData = @{
          timestamp = "2024-01-01T12:00:00Z"
          user = "john.doe"
          src_ip = "192.168.1.100"
          action = "Logon"
          result = "Success"
          logon_type = "Interactive"
          target_app = "Windows"
        }
      }
    }
    "ProcessEvent" {
      return @{
        Description = "Process creation, termination, and modification"
        RequiredFields = @("TimeGenerated", "EventType", "DvcOs")
        MappingFunction = "Resolve-AsimProcessEvent"
        SampleData = @{
          timestamp = "2024-01-01T12:00:00Z"
          process_name = "notepad.exe"
          process_id = 1234
          parent_process = "explorer.exe"
          command_line = "notepad.exe document.txt"
          user = "john.doe"
          action = "ProcessCreated"
        }
      }
    }
    "FileEvent" {
      return @{
        Description = "File system operations"
        RequiredFields = @("TimeGenerated", "EventType", "DvcOs")
        MappingFunction = "Resolve-AsimFileEvent"
        SampleData = @{
          timestamp = "2024-01-01T12:00:00Z"
          file_path = "C:\\Users\\john\\document.txt"
          file_name = "document.txt"
          action = "FileCreated"
          process_name = "notepad.exe"
          user = "john.doe"
          file_size = 1024
        }
      }
    }
    "RegistryEvent" {
      return @{
        Description = "Windows Registry operations"
        RequiredFields = @("TimeGenerated", "EventType", "DvcOs")
        MappingFunction = "Resolve-AsimRegistryEvent"
        SampleData = @{
          timestamp = "2024-01-01T12:00:00Z"
          registry_key = "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion"
          registry_value = "ProgramFilesDir"
          action = "RegistryValueSet"
          process_name = "setup.exe"
          user = "SYSTEM"
        }
      }
    }
    "WebSession" {
      return @{
        Description = "Web/HTTP requests and responses"
        RequiredFields = @("TimeGenerated", "EventType", "EventResult")
        MappingFunction = "Resolve-AsimWebSession"
        SampleData = @{
          timestamp = "2024-01-01T12:00:00Z"
          url = "https://example.com/api/data"
          method = "GET"
          src_ip = "192.168.1.100"
          user_agent = "Mozilla/5.0"
          response_code = 200
          bytes_sent = 512
          bytes_received = 1024
        }
      }
    }
    "AuditEvent" {
      return @{
        Description = "Audit and compliance events"
        RequiredFields = @("TimeGenerated", "EventType", "EventResult")
        MappingFunction = "Resolve-AsimAuditEvent"
        SampleData = @{
          timestamp = "2024-01-01T12:00:00Z"
          object = "SecurityPolicy"
          operation = "PolicyChange"
          user = "admin"
          result = "Success"
          details = "Password policy updated"
        }
      }
    }
    default {
      throw "Unsupported ASIM schema: $Schema. Supported schemas: NetworkSession, DnsActivity, Authentication, ProcessEvent, FileEvent, RegistryEvent, WebSession, AuditEvent"
    }
  }
}

function Resolve-AsimNetworkSession {
  param([Object]$Event)
  
  # =====================================================================================
  # ASIM NETWORK SESSION MAPPING
  # =====================================================================================
  # Maps incoming event data to ASIM NetworkSession schema
  # Reference: https://learn.microsoft.com/en-us/azure/sentinel/normalization-schema-network
  # =====================================================================================
  
  return @{
    # *** REQUIRED FIELDS ***
    "TimeGenerated" = if ($Event.timestamp) { $Event.timestamp } elseif ($Event.TimeGenerated) { $Event.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
    "EventType" = "NetworkSession"
    "EventResult" = if ($Event.result) { $Event.result } elseif ($Event.action -eq "Allow") { "Success" } elseif ($Event.action -eq "Block") { "Failure" } else { "Success" }
    
    # *** COMMON FIELDS ***
    "EventVendor" = if ($Event.vendor) { $Event.vendor } else { "Custom" }
    "EventProduct" = if ($Event.product) { $Event.product } else { "DataIngestion" }
    "EventSchema" = "NetworkSession"
    "EventSchemaVersion" = "0.2.6"
    "EventCount" = if ($Event.count) { $Event.count } else { 1 }
    "EventSeverity" = if ($Event.severity) { $Event.severity } elseif ($Event.action -eq "Block") { "Medium" } else { "Informational" }
    
    # *** SOURCE FIELDS ***
    "SrcIpAddr" = if ($Event.src_ip) { $Event.src_ip } elseif ($Event.sourceIP) { $Event.sourceIP } elseif ($Event.SourceIP) { $Event.SourceIP } else { "" }
    "SrcPortNumber" = if ($Event.src_port) { $Event.src_port } elseif ($Event.sourcePort) { $Event.sourcePort } else { $null }
    "SrcHostname" = if ($Event.src_hostname) { $Event.src_hostname } elseif ($Event.sourceHost) { $Event.sourceHost } else { "" }
    "SrcDvcId" = if ($Event.src_device_id) { $Event.src_device_id } else { "" }
    
    # *** DESTINATION FIELDS ***
    "DstIpAddr" = if ($Event.dst_ip) { $Event.dst_ip } elseif ($Event.destinationIP) { $Event.destinationIP } elseif ($Event.DestinationIP) { $Event.DestinationIP } else { "" }
    "DstPortNumber" = if ($Event.dst_port) { $Event.dst_port } elseif ($Event.destinationPort) { $Event.destinationPort } else { $null }
    "DstHostname" = if ($Event.dst_hostname) { $Event.dst_hostname } elseif ($Event.destinationHost) { $Event.destinationHost } else { "" }
    "DstDvcId" = if ($Event.dst_device_id) { $Event.dst_device_id } else { "" }
    
    # *** NETWORK FIELDS ***
    "NetworkProtocol" = if ($Event.protocol) { $Event.protocol.ToUpper() } elseif ($Event.Protocol) { $Event.Protocol.ToUpper() } else { "" }
    "NetworkDirection" = if ($Event.direction) { $Event.direction } else { "Unknown" }
    "NetworkBytes" = if ($Event.bytes_total) { $Event.bytes_total } elseif ($Event.bytes) { $Event.bytes } else { $null }
    "NetworkPackets" = if ($Event.packets_total) { $Event.packets_total } elseif ($Event.packets) { $Event.packets } else { $null }
    
    # *** DEVICE FIELDS ***
    "DvcAction" = if ($Event.action) { $Event.action } elseif ($Event.verdict) { $Event.verdict } else { "Allow" }
    "DvcInboundInterface" = if ($Event.in_interface) { $Event.in_interface } else { "" }
    "DvcOutboundInterface" = if ($Event.out_interface) { $Event.out_interface } else { "" }
    "DvcHostname" = if ($Event.device_hostname) { $Event.device_hostname } elseif ($Event.hostname) { $Event.hostname } else { "" }
    "DvcIpAddr" = if ($Event.device_ip) { $Event.device_ip } else { "" }
    
    # *** RULE FIELDS ***
    "RuleName" = if ($Event.rule_name) { $Event.rule_name } elseif ($Event.rule) { $Event.rule } else { "" }
    "RuleNumber" = if ($Event.rule_number) { $Event.rule_number } else { $null }
    
    # *** SESSION FIELDS ***
    "SessionId" = if ($Event.session_id) { $Event.session_id } elseif ($Event.connection_id) { $Event.connection_id } else { "" }
    "NetworkSessionId" = if ($Event.session_id) { $Event.session_id } elseif ($Event.flow_id) { $Event.flow_id } else { "" }
    
    # *** ADDITIONAL FIELDS ***
    "AdditionalFields" = if ($Event.additional_fields) { $Event.additional_fields } else { ($Event | ConvertTo-Json -Compress) }
  }
}

function Resolve-AsimDnsActivity {
  param([Object]$Event)
  
  # =====================================================================================
  # ASIM DNS ACTIVITY MAPPING  
  # =====================================================================================
  # Maps incoming event data to ASIM DnsActivity schema
  # Reference: https://learn.microsoft.com/en-us/azure/sentinel/normalization-schema-dns
  # =====================================================================================
  
  return @{
    # *** REQUIRED FIELDS ***
    "TimeGenerated" = if ($Event.timestamp) { $Event.timestamp } elseif ($Event.TimeGenerated) { $Event.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
    "EventType" = "DnsQuery"
    "DvcAction" = if ($Event.action) { $Event.action } else { "Allowed" }
    
    # *** COMMON FIELDS ***
    "EventVendor" = if ($Event.vendor) { $Event.vendor } else { "Custom" }
    "EventProduct" = if ($Event.product) { $Event.product } else { "DataIngestion" }
    "EventSchema" = "DnsActivity"
    "EventSchemaVersion" = "0.1.7"
    "EventCount" = if ($Event.count) { $Event.count } else { 1 }
    "EventResult" = if ($Event.result) { $Event.result } elseif ($Event.response_code -eq "NOERROR") { "Success" } else { "Failure" }
    "EventSeverity" = if ($Event.severity) { $Event.severity } else { "Informational" }
    
    # *** DNS QUERY FIELDS ***
    "DnsQuery" = if ($Event.query) { $Event.query } elseif ($Event.domain) { $Event.domain } elseif ($Event.question) { $Event.question } else { "" }
    "DnsQueryType" = if ($Event.query_type) { $Event.query_type } elseif ($Event.record_type) { $Event.record_type } else { "A" }
    "DnsQueryTypeName" = if ($Event.query_type_name) { $Event.query_type_name } elseif ($Event.query_type) { $Event.query_type } else { "A" }
    "DnsQueryClass" = if ($Event.query_class) { $Event.query_class } else { "IN" }
    
    # *** DNS RESPONSE FIELDS ***
    "DnsResponseCode" = if ($Event.response_code) { $Event.response_code } elseif ($Event.rcode) { $Event.rcode } else { "NOERROR" }
    "DnsResponseCodeName" = if ($Event.response_code_name) { $Event.response_code_name } elseif ($Event.response_code) { $Event.response_code } else { "NOERROR" }
    "DnsResponseName" = if ($Event.answer) { $Event.answer } elseif ($Event.response) { $Event.response } else { "" }
    "DnsFlags" = if ($Event.flags) { $Event.flags } else { "" }
    
    # *** SOURCE FIELDS ***
    "SrcIpAddr" = if ($Event.src_ip) { $Event.src_ip } elseif ($Event.client_ip) { $Event.client_ip } elseif ($Event.sourceIP) { $Event.sourceIP } else { "" }
    "SrcPortNumber" = if ($Event.src_port) { $Event.src_port } elseif ($Event.client_port) { $Event.client_port } else { $null }
    "SrcHostname" = if ($Event.src_hostname) { $Event.src_hostname } elseif ($Event.client_hostname) { $Event.client_hostname } else { "" }
    
    # *** DESTINATION FIELDS (DNS Server) ***
    "DstIpAddr" = if ($Event.dns_server) { $Event.dns_server } elseif ($Event.server_ip) { $Event.server_ip } elseif ($Event.dst_ip) { $Event.dst_ip } else { "" }
    "DstPortNumber" = if ($Event.dns_port) { $Event.dns_port } elseif ($Event.dst_port) { $Event.dst_port } else { 53 }
    "DstHostname" = if ($Event.dns_server_name) { $Event.dns_server_name } else { "" }
    
    # *** DEVICE FIELDS ***
    "DvcHostname" = if ($Event.device_hostname) { $Event.device_hostname } elseif ($Event.hostname) { $Event.hostname } else { "" }
    "DvcIpAddr" = if ($Event.device_ip) { $Event.device_ip } else { "" }
    "DvcDomain" = if ($Event.device_domain) { $Event.device_domain } else { "" }
    
    # *** NETWORK FIELDS ***
    "NetworkProtocol" = if ($Event.protocol) { $Event.protocol.ToUpper() } else { "UDP" }
    
    # *** ADDITIONAL FIELDS ***
    "AdditionalFields" = if ($Event.additional_fields) { $Event.additional_fields } else { ($Event | ConvertTo-Json -Compress) }
  }
}

function Resolve-AsimAuthentication {
  param([Object]$Event)
  
  # =====================================================================================
  # ASIM AUTHENTICATION MAPPING
  # =====================================================================================
  # Maps incoming event data to ASIM Authentication schema
  # Reference: https://learn.microsoft.com/en-us/azure/sentinel/normalization-schema-authentication
  # =====================================================================================
  
  return @{
    # *** REQUIRED FIELDS ***
    "TimeGenerated" = if ($Event.timestamp) { $Event.timestamp } elseif ($Event.TimeGenerated) { $Event.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
    "EventType" = if ($Event.event_type) { $Event.event_type } else { "Logon" }
    "EventResult" = if ($Event.result) { $Event.result } elseif ($Event.action -eq "Success") { "Success" } elseif ($Event.action -eq "Failed") { "Failure" } else { "Success" }
    
    # *** COMMON FIELDS ***
    "EventVendor" = if ($Event.vendor) { $Event.vendor } else { "Custom" }
    "EventProduct" = if ($Event.product) { $Event.product } else { "DataIngestion" }
    "EventSchema" = "Authentication"
    "EventSchemaVersion" = "0.1.3"
    "EventCount" = if ($Event.count) { $Event.count } else { 1 }
    "EventSeverity" = if ($Event.severity) { $Event.severity } elseif ($Event.result -eq "Failure") { "Medium" } else { "Informational" }
    "EventMessage" = if ($Event.message) { $Event.message } else { "Authentication event" }
    
    # *** USER FIELDS ***
    "TargetUserId" = if ($Event.user_id) { $Event.user_id } elseif ($Event.userId) { $Event.userId } else { "" }
    "TargetUsername" = if ($Event.user) { $Event.user } elseif ($Event.username) { $Event.username } elseif ($Event.account) { $Event.account } else { "" }
    "TargetUserType" = if ($Event.user_type) { $Event.user_type } else { "Regular" }
    "TargetUserDomain" = if ($Event.domain) { $Event.domain } elseif ($Event.user_domain) { $Event.user_domain } else { "" }
    
    # *** SOURCE FIELDS ***
    "SrcIpAddr" = if ($Event.src_ip) { $Event.src_ip } elseif ($Event.client_ip) { $Event.client_ip } elseif ($Event.sourceIP) { $Event.sourceIP } else { "" }
    "SrcPortNumber" = if ($Event.src_port) { $Event.src_port } elseif ($Event.client_port) { $Event.client_port } else { $null }
    "SrcHostname" = if ($Event.src_hostname) { $Event.src_hostname } elseif ($Event.client_hostname) { $Event.client_hostname } else { "" }
    "SrcDvcId" = if ($Event.src_device_id) { $Event.src_device_id } else { "" }
    
    # *** TARGET APPLICATION FIELDS ***
    "TargetAppName" = if ($Event.target_app) { $Event.target_app } elseif ($Event.application) { $Event.application } elseif ($Event.service) { $Event.service } else { "" }
    "TargetAppType" = if ($Event.app_type) { $Event.app_type } else { "" }
    "TargetUrl" = if ($Event.target_url) { $Event.target_url } elseif ($Event.url) { $Event.url } else { "" }
    
    # *** AUTHENTICATION FIELDS ***
    "LogonMethod" = if ($Event.logon_method) { $Event.logon_method } elseif ($Event.auth_method) { $Event.auth_method } else { "" }
    "LogonProtocol" = if ($Event.logon_protocol) { $Event.logon_protocol } elseif ($Event.protocol) { $Event.protocol } else { "" }
    "LogonTarget" = if ($Event.logon_target) { $Event.logon_target } else { "" }
    "LogonType" = if ($Event.logon_type) { $Event.logon_type } else { "Interactive" }
    
    # *** DEVICE FIELDS ***
    "DvcHostname" = if ($Event.device_hostname) { $Event.device_hostname } elseif ($Event.hostname) { $Event.hostname } else { "" }
    "DvcIpAddr" = if ($Event.device_ip) { $Event.device_ip } else { "" }
    "DvcDomain" = if ($Event.device_domain) { $Event.device_domain } else { "" }
    "DvcOs" = if ($Event.os) { $Event.os } elseif ($Event.operating_system) { $Event.operating_system } else { "" }
    
    # *** HTTP FIELDS (for web authentication) ***
    "HttpUserAgent" = if ($Event.user_agent) { $Event.user_agent } elseif ($Event.useragent) { $Event.useragent } else { "" }
    "HttpRequestMethod" = if ($Event.http_method) { $Event.http_method } elseif ($Event.method) { $Event.method } else { "" }
    
    # *** ADDITIONAL FIELDS ***
    "AdditionalFields" = if ($Event.additional_fields) { $Event.additional_fields } else { ($Event | ConvertTo-Json -Compress) }
  }
}

function Resolve-AsimProcessEvent {
  param([Object]$Event)
  
  # =====================================================================================
  # ASIM PROCESS EVENT MAPPING
  # =====================================================================================
  # Maps incoming event data to ASIM ProcessEvent schema
  # Reference: https://learn.microsoft.com/en-us/azure/sentinel/normalization-schema-process-event
  # =====================================================================================
  
  return @{
    # *** REQUIRED FIELDS ***
    "TimeGenerated" = if ($Event.timestamp) { $Event.timestamp } elseif ($Event.TimeGenerated) { $Event.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
    "EventType" = if ($Event.event_type) { $Event.event_type } else { "ProcessCreated" }
    "DvcOs" = if ($Event.os) { $Event.os } elseif ($Event.operating_system) { $Event.operating_system } else { "Windows" }
    
    # *** COMMON FIELDS ***
    "EventVendor" = if ($Event.vendor) { $Event.vendor } else { "Custom" }
    "EventProduct" = if ($Event.product) { $Event.product } else { "DataIngestion" }
    "EventSchema" = "ProcessEvent"
    "EventSchemaVersion" = "0.1.4"
    "EventCount" = if ($Event.count) { $Event.count } else { 1 }
    "EventResult" = if ($Event.result) { $Event.result } else { "Success" }
    "EventSeverity" = if ($Event.severity) { $Event.severity } else { "Informational" }
    
    # *** TARGET PROCESS FIELDS ***
    "TargetProcessName" = if ($Event.process_name) { $Event.process_name } elseif ($Event.image) { $Event.image } elseif ($Event.executable) { $Event.executable } else { "" }
    "TargetProcessId" = if ($Event.process_id) { $Event.process_id } elseif ($Event.pid) { $Event.pid } else { $null }
    "TargetProcessGuid" = if ($Event.process_guid) { $Event.process_guid } else { "" }
    "TargetProcessCommandLine" = if ($Event.command_line) { $Event.command_line } elseif ($Event.cmdline) { $Event.cmdline } else { "" }
    "TargetProcessCurrentDirectory" = if ($Event.current_directory) { $Event.current_directory } elseif ($Event.working_directory) { $Event.working_directory } else { "" }
    
    # *** ACTING PROCESS FIELDS (Parent) ***
    "ActingProcessName" = if ($Event.parent_process) { $Event.parent_process } elseif ($Event.parent_image) { $Event.parent_image } else { "" }
    "ActingProcessId" = if ($Event.parent_process_id) { $Event.parent_process_id } elseif ($Event.parent_pid) { $Event.parent_pid } else { $null }
    "ActingProcessGuid" = if ($Event.parent_process_guid) { $Event.parent_process_guid } else { "" }
    "ActingProcessCommandLine" = if ($Event.parent_command_line) { $Event.parent_command_line } elseif ($Event.parent_cmdline) { $Event.parent_cmdline } else { "" }
    
    # *** USER FIELDS ***
    "ActorUserId" = if ($Event.user_id) { $Event.user_id } elseif ($Event.userId) { $Event.userId } else { "" }
    "ActorUsername" = if ($Event.user) { $Event.user } elseif ($Event.username) { $Event.username } elseif ($Event.account) { $Event.account } else { "" }
    "ActorUserDomain" = if ($Event.domain) { $Event.domain } elseif ($Event.user_domain) { $Event.user_domain } else { "" }
    "ActorUserType" = if ($Event.user_type) { $Event.user_type } else { "Regular" }
    
    # *** DEVICE FIELDS ***
    "DvcHostname" = if ($Event.device_hostname) { $Event.device_hostname } elseif ($Event.hostname) { $Event.hostname } elseif ($Event.computer) { $Event.computer } else { "" }
    "DvcIpAddr" = if ($Event.device_ip) { $Event.device_ip } else { "" }
    "DvcDomain" = if ($Event.device_domain) { $Event.device_domain } else { "" }
    "DvcId" = if ($Event.device_id) { $Event.device_id } else { "" }
    
    # *** HASH FIELDS ***
    "TargetProcessMD5" = if ($Event.md5) { $Event.md5 } elseif ($Event.hash_md5) { $Event.hash_md5 } else { "" }
    "TargetProcessSHA1" = if ($Event.sha1) { $Event.sha1 } elseif ($Event.hash_sha1) { $Event.hash_sha1 } else { "" }
    "TargetProcessSHA256" = if ($Event.sha256) { $Event.sha256 } elseif ($Event.hash_sha256) { $Event.hash_sha256 } else { "" }
    
    # *** ADDITIONAL FIELDS ***
    "AdditionalFields" = if ($Event.additional_fields) { $Event.additional_fields } else { ($Event | ConvertTo-Json -Compress) }
  }
}

function Resolve-AsimFileEvent {
  param([Object]$Event)
  
  return @{
    # *** REQUIRED FIELDS ***
    "TimeGenerated" = if ($Event.timestamp) { $Event.timestamp } elseif ($Event.TimeGenerated) { $Event.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
    "EventType" = if ($Event.event_type) { $Event.event_type } else { "FileCreated" }
    "DvcOs" = if ($Event.os) { $Event.os } elseif ($Event.operating_system) { $Event.operating_system } else { "Windows" }
    
    # *** COMMON FIELDS ***
    "EventVendor" = if ($Event.vendor) { $Event.vendor } else { "Custom" }
    "EventProduct" = if ($Event.product) { $Event.product } else { "DataIngestion" }
    "EventSchema" = "FileEvent"
    "EventSchemaVersion" = "0.2.1"
    "EventResult" = if ($Event.result) { $Event.result } else { "Success" }
    
    # *** FILE FIELDS ***
    "TargetFilePath" = if ($Event.file_path) { $Event.file_path } elseif ($Event.path) { $Event.path } else { "" }
    "TargetFileName" = if ($Event.file_name) { $Event.file_name } elseif ($Event.name) { $Event.name } else { "" }
    "TargetFileSize" = if ($Event.file_size) { $Event.file_size } elseif ($Event.size) { $Event.size } else { $null }
    "TargetFileMD5" = if ($Event.md5) { $Event.md5 } else { "" }
    "TargetFileSHA1" = if ($Event.sha1) { $Event.sha1 } else { "" }
    "TargetFileSHA256" = if ($Event.sha256) { $Event.sha256 } else { "" }
    
    # *** PROCESS FIELDS ***
    "ActingProcessName" = if ($Event.process_name) { $Event.process_name } else { "" }
    "ActingProcessId" = if ($Event.process_id) { $Event.process_id } else { $null }
    
    # *** USER FIELDS ***
    "ActorUsername" = if ($Event.user) { $Event.user } else { "" }
    "ActorUserId" = if ($Event.user_id) { $Event.user_id } else { "" }
    
    # *** DEVICE FIELDS ***
    "DvcHostname" = if ($Event.hostname) { $Event.hostname } else { "" }
    "DvcIpAddr" = if ($Event.device_ip) { $Event.device_ip } else { "" }
    
    # *** ADDITIONAL FIELDS ***
    "AdditionalFields" = ($Event | ConvertTo-Json -Compress)
  }
}

function Resolve-AsimRegistryEvent {
  param([Object]$Event)
  
  return @{
    # *** REQUIRED FIELDS ***
    "TimeGenerated" = if ($Event.timestamp) { $Event.timestamp } elseif ($Event.TimeGenerated) { $Event.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
    "EventType" = if ($Event.event_type) { $Event.event_type } else { "RegistryValueSet" }
    "DvcOs" = "Windows"  # Registry events are Windows-specific
    
    # *** COMMON FIELDS ***
    "EventVendor" = if ($Event.vendor) { $Event.vendor } else { "Custom" }
    "EventProduct" = if ($Event.product) { $Event.product } else { "DataIngestion" }
    "EventSchema" = "RegistryEvent"
    "EventSchemaVersion" = "0.1.2"
    "EventResult" = if ($Event.result) { $Event.result } else { "Success" }
    
    # *** REGISTRY FIELDS ***
    "RegistryKey" = if ($Event.registry_key) { $Event.registry_key } elseif ($Event.key) { $Event.key } else { "" }
    "RegistryValue" = if ($Event.registry_value) { $Event.registry_value } elseif ($Event.value) { $Event.value } else { "" }
    "RegistryValueType" = if ($Event.value_type) { $Event.value_type } else { "" }
    "RegistryValueData" = if ($Event.value_data) { $Event.value_data } elseif ($Event.data) { $Event.data } else { "" }
    
    # *** PROCESS FIELDS ***
    "ActingProcessName" = if ($Event.process_name) { $Event.process_name } else { "" }
    "ActingProcessId" = if ($Event.process_id) { $Event.process_id } else { $null }
    
    # *** USER FIELDS ***
    "ActorUsername" = if ($Event.user) { $Event.user } else { "" }
    "ActorUserId" = if ($Event.user_id) { $Event.user_id } else { "" }
    
    # *** DEVICE FIELDS ***
    "DvcHostname" = if ($Event.hostname) { $Event.hostname } else { "" }
    "DvcIpAddr" = if ($Event.device_ip) { $Event.device_ip } else { "" }
    
    # *** ADDITIONAL FIELDS ***
    "AdditionalFields" = ($Event | ConvertTo-Json -Compress)
  }
}

function Resolve-AsimWebSession {
  param([Object]$Event)
  
  return @{
    # *** REQUIRED FIELDS ***
    "TimeGenerated" = if ($Event.timestamp) { $Event.timestamp } elseif ($Event.TimeGenerated) { $Event.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
    "EventType" = "HTTPSession"
    "EventResult" = if ($Event.result) { $Event.result } elseif ($Event.response_code -lt 400) { "Success" } else { "Failure" }
    
    # *** COMMON FIELDS ***
    "EventVendor" = if ($Event.vendor) { $Event.vendor } else { "Custom" }
    "EventProduct" = if ($Event.product) { $Event.product } else { "DataIngestion" }
    "EventSchema" = "WebSession"
    "EventSchemaVersion" = "0.2.6"
    "EventSeverity" = if ($Event.severity) { $Event.severity } else { "Informational" }
    
    # *** HTTP FIELDS ***
    "Url" = if ($Event.url) { $Event.url } elseif ($Event.uri) { $Event.uri } else { "" }
    "HttpMethod" = if ($Event.method) { $Event.method.ToUpper() } elseif ($Event.http_method) { $Event.http_method.ToUpper() } else { "GET" }
    "HttpStatusCode" = if ($Event.response_code) { $Event.response_code } elseif ($Event.status_code) { $Event.status_code } else { $null }
    "HttpUserAgent" = if ($Event.user_agent) { $Event.user_agent } elseif ($Event.useragent) { $Event.useragent } else { "" }
    "HttpReferrer" = if ($Event.referrer) { $Event.referrer } elseif ($Event.referer) { $Event.referer } else { "" }
    
    # *** SOURCE FIELDS ***
    "SrcIpAddr" = if ($Event.src_ip) { $Event.src_ip } elseif ($Event.client_ip) { $Event.client_ip } else { "" }
    "SrcPortNumber" = if ($Event.src_port) { $Event.src_port } elseif ($Event.client_port) { $Event.client_port } else { $null }
    "SrcHostname" = if ($Event.src_hostname) { $Event.src_hostname } else { "" }
    
    # *** DESTINATION FIELDS ***
    "DstIpAddr" = if ($Event.dst_ip) { $Event.dst_ip } elseif ($Event.server_ip) { $Event.server_ip } else { "" }
    "DstPortNumber" = if ($Event.dst_port) { $Event.dst_port } elseif ($Event.server_port) { $Event.server_port } else { 80 }
    "DstHostname" = if ($Event.dst_hostname) { $Event.dst_hostname } elseif ($Event.server_name) { $Event.server_name } else { "" }
    
    # *** USER FIELDS ***
    "SrcUsername" = if ($Event.user) { $Event.user } elseif ($Event.username) { $Event.username } else { "" }
    "SrcUserId" = if ($Event.user_id) { $Event.user_id } else { "" }
    
    # *** NETWORK FIELDS ***
    "NetworkBytes" = if ($Event.bytes_total) { $Event.bytes_total } else { $null }
    "NetworkProtocol" = "TCP"
    
    # *** ADDITIONAL FIELDS ***
    "AdditionalFields" = ($Event | ConvertTo-Json -Compress)
  }
}

function Resolve-AsimAuditEvent {
  param([Object]$Event)
  
  return @{
    # *** REQUIRED FIELDS ***
    "TimeGenerated" = if ($Event.timestamp) { $Event.timestamp } elseif ($Event.TimeGenerated) { $Event.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
    "EventType" = if ($Event.event_type) { $Event.event_type } else { "AuditPolicyChange" }
    "EventResult" = if ($Event.result) { $Event.result } else { "Success" }
    
    # *** COMMON FIELDS ***
    "EventVendor" = if ($Event.vendor) { $Event.vendor } else { "Custom" }
    "EventProduct" = if ($Event.product) { $Event.product } else { "DataIngestion" }
    "EventSchema" = "AuditEvent"
    "EventSchemaVersion" = "0.1.0"
    "EventSeverity" = if ($Event.severity) { $Event.severity } else { "Informational" }
    
    # *** OBJECT FIELDS ***
    "Object" = if ($Event.object) { $Event.object } elseif ($Event.target) { $Event.target } else { "" }
    "Operation" = if ($Event.operation) { $Event.operation } elseif ($Event.action) { $Event.action } else { "" }
    "Value" = if ($Event.value) { $Event.value } elseif ($Event.details) { $Event.details } else { "" }
    
    # *** USER FIELDS ***
    "ActorUsername" = if ($Event.user) { $Event.user } elseif ($Event.username) { $Event.username } else { "" }
    "ActorUserId" = if ($Event.user_id) { $Event.user_id } else { "" }
    "ActorUserDomain" = if ($Event.domain) { $Event.domain } else { "" }
    
    # *** SOURCE FIELDS ***
    "SrcIpAddr" = if ($Event.src_ip) { $Event.src_ip } elseif ($Event.client_ip) { $Event.client_ip } else { "" }
    "SrcHostname" = if ($Event.src_hostname) { $Event.src_hostname } else { "" }
    
    # *** DEVICE FIELDS ***
    "DvcHostname" = if ($Event.hostname) { $Event.hostname } else { "" }
    "DvcIpAddr" = if ($Event.device_ip) { $Event.device_ip } else { "" }
    
    # *** ADDITIONAL FIELDS ***
    "AdditionalFields" = ($Event | ConvertTo-Json -Compress)
  }
}

function Build-AsimBodyJson {
  param([string]$InputJsonPath, [Object[]]$Events, [string]$Schema)
  
  $schemaConfig = Get-AsimFieldMapping -Schema $Schema
  $mappingFunction = $schemaConfig.MappingFunction
  
  Write-Host "Using ASIM Schema: $Schema ($($schemaConfig.Description))" -ForegroundColor Cyan
  
  if ($InputJsonPath) {
    # Handle relative paths
    if (-not [System.IO.Path]::IsPathRooted($InputJsonPath)) {
      $InputJsonPath = Join-Path (Get-Location) $InputJsonPath
    }
    
    if (-not (Test-Path $InputJsonPath)) {
      throw "JSON file not found at path: $InputJsonPath"
    }
    
    Write-Host "Reading JSON from: $InputJsonPath" -ForegroundColor Yellow
    $raw = Get-Content -Path $InputJsonPath -Raw -ErrorAction Stop
    $eventsArray = $raw | ConvertFrom-Json
    
    $processedEvents = @()
    foreach ($eventItem in $eventsArray) {
      $mappedEvent = & $mappingFunction -Event $eventItem
      $processedEvents += $mappedEvent
    }
    
    Write-Host "Processed $($processedEvents.Count) events from JSON file" -ForegroundColor Cyan
    return @{
      Json = ($processedEvents | ConvertTo-Json -Depth 64 -AsArray)
      Count = $processedEvents.Count
    }
  }
  elseif ($Events) {
    if ($Events -isnot [System.Array]) { $Events = @($Events) }
    
    $processedEvents = @()
    foreach ($eventItem in $Events) {
      $mappedEvent = & $mappingFunction -Event $eventItem
      $processedEvents += $mappedEvent
    }
    
    Write-Host "Processed $($processedEvents.Count) events from parameter array" -ForegroundColor Cyan
    return @{
      Json = ($processedEvents | ConvertTo-Json -Depth 64 -AsArray)
      Count = $processedEvents.Count
    }
  }
  else {
    # Generate sample data for the specified schema
    $sampleEvent = $schemaConfig.SampleData
    $mappedEvent = & $mappingFunction -Event $sampleEvent
    $sample = @($mappedEvent)
    
    Write-Host "Generated 1 sample event for testing" -ForegroundColor Cyan
    return @{
      Json = ($sample | ConvertTo-Json -Depth 64 -AsArray)
      Count = 1
    }
  }
}

function Compress-GzipBytes {
  param([byte[]]$Bytes)
  $outStream = New-Object System.IO.MemoryStream
  $gzip = New-Object System.IO.Compression.GzipStream($outStream, [System.IO.Compression.CompressionMode]::Compress)
  $gzip.Write($Bytes, 0, $Bytes.Length)
  $gzip.Close()
  $out = $outStream.ToArray()
  $outStream.Dispose()
  return $out
}

function Test-AsimFieldValidation {
  param([string]$JsonBody, [string]$Schema)
  
  $schemaConfig = Get-AsimFieldMapping -Schema $Schema
  $requiredFields = $schemaConfig.RequiredFields
  
  try {
    $events = $JsonBody | ConvertFrom-Json
    if ($events -isnot [System.Array]) { $events = @($events) }
    
    $validationResults = @()
    foreach ($eventItem in $events) {
      $missingFields = @()
      foreach ($field in $requiredFields) {
        if (-not $eventItem.$field -or $eventItem.$field -eq "") {
          $missingFields += $field
        }
      }
      
      $validationResults += @{
        Event = $eventItem
        MissingRequiredFields = $missingFields
        IsValid = ($missingFields.Count -eq 0)
      }
    }
    
    return $validationResults
  }
  catch {
    throw "Failed to validate ASIM fields: $_"
  }
}

# =====================================================================================
# MAIN EXECUTION
# =====================================================================================

Write-Host "ASIM Data Ingestion Script - Schema: $AsimSchema" -ForegroundColor Green
Write-Host "Stream Name: $StreamName" -ForegroundColor Cyan

# Build target URI
$uri = "$DceBaseUrl/dataCollectionRules/$DcrImmutableId/streams/$StreamName" + "?api-version=2023-01-01"
Write-Host "Target URI: $uri" -ForegroundColor Cyan

# Build ASIM-compliant body
$buildResult = Build-AsimBodyJson -InputJsonPath $InputJsonPath -Events $Events -Schema $AsimSchema
$bodyJson = $buildResult.Json
$eventCount = $buildResult.Count

if ($ValidateOnly) {
  Write-Host "`nValidation Mode - Field Mapping Results:" -ForegroundColor Yellow
  $validation = Test-AsimFieldValidation -JsonBody $bodyJson -Schema $AsimSchema
  
  foreach ($result in $validation) {
    if ($result.IsValid) {
      Write-Host "✅ Event is valid for ASIM $AsimSchema schema" -ForegroundColor Green
    } else {
      Write-Host "❌ Event missing required fields: $($result.MissingRequiredFields -join ', ')" -ForegroundColor Red
    }
  }
  
  if ($ShowBody) {
    Write-Host "`nMapped ASIM Data:" -ForegroundColor Magenta
    Write-Host $bodyJson -ForegroundColor Gray
  }
  
  Write-Host "`nValidation complete. Use without -ValidateOnly to send data." -ForegroundColor Yellow
  return
}

if ($ShowBody) {
  Write-Host "`nASIM-mapped request body:" -ForegroundColor Magenta
  Write-Host $bodyJson -ForegroundColor Gray
}

# Acquire token
Write-Host "`nAcquiring OAuth token..." -ForegroundColor Yellow
$token = Get-OAuthToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

# Prepare request headers
$headers = @{ 
  Authorization = "Bearer $token"
  'Content-Type' = 'application/json'
}

# Send data with retry logic
Write-Host "`nSending ASIM data to DCR with retry protection..." -ForegroundColor Yellow

$sendResult = $null
if ($Gzip) {
  Write-Host "Compressing payload with gzip..." -ForegroundColor Yellow
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)
  $gz = Compress-GzipBytes -Bytes $bytes
  $headers['Content-Encoding'] = 'gzip'
  
  $sendResult = Send-DataWithRetry -Uri $uri -Headers $headers -Body $bodyJson -CompressedBody $gz -ShowRetryDetails
} else {
  $sendResult = Send-DataWithRetry -Uri $uri -Headers $headers -Body $bodyJson -ShowRetryDetails
}

# Handle results
if ($sendResult.Success) {
  Write-Host "✅ SUCCESS: ASIM data ingested successfully!" -ForegroundColor Green
  Write-Host "   Schema: $AsimSchema" -ForegroundColor Cyan
  Write-Host "   Events: $eventCount" -ForegroundColor Cyan
  Write-Host "   Stream: $StreamName" -ForegroundColor Cyan
  Write-Host "   Status: HTTP $($sendResult.Response.StatusCode)" -ForegroundColor Cyan
  
  if ($ShowBody -and $sendResult.Response.Content) { 
    Write-Host "Response: $($sendResult.Response.Content)" -ForegroundColor Gray 
  }
} else {
  Write-Host "❌ FAILURE: Data ingestion failed!" -ForegroundColor Red
  
  if ($sendResult.MaxRetriesExceeded) {
    Write-Host "💀 CRITICAL DATA LOSS: All retry attempts exhausted!" -ForegroundColor Red
    Write-Host "📋 RECOVERY ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "   1. Check DCR limits and current ingestion rate" -ForegroundColor Yellow
    Write-Host "   2. Verify network connectivity and authentication" -ForegroundColor Yellow
    Write-Host "   3. Consider reducing batch size or implementing queue persistence" -ForegroundColor Yellow
    Write-Host "   4. Re-run script with same data to retry ingestion" -ForegroundColor Yellow
  }
  
  if ($sendResult.Error) {
    Write-Host "Error details: $($sendResult.Error)" -ForegroundColor Red
  }
  
  # Exit with error code to indicate failure
  exit 1
}
