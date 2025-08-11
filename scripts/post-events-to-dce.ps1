# Azure Data Collection Endpoint Event Poster
# Posts JSON events to Azure Monitor Data Collection Endpoints (DCE)
# Compatible with custom Data Collection Rules (DCR)

# NOTE: Create GitHub secrets in your repository for the following:
# - AZURE_TENANT_ID: Your Azure AD tenant ID
# - AZURE_CLIENT_ID: Your Azure AD application client ID  
# - AZURE_CLIENT_SECRET: Your Azure AD application client secret
param(
  [Parameter(Mandatory=$false)] [string]$TenantId = $env:AZURE_TENANT_ID,
  [Parameter(Mandatory=$false)] [string]$ClientId = $env:AZURE_CLIENT_ID,  # From: az ad app create --display-name "DCR-API-Ingestion-App" --query "appId"
  [Parameter(Mandatory=$true)] [string]$ClientSecret,  # Use: $env:AZURE_CLIENT_SECRET (from az ad app credential reset)
  [Parameter(Mandatory=$false)] [string]$DceBaseUrl = "https://dce-api-ingestion-dev-1tty.australiaeast-1.ingest.monitor.azure.com",  # From: az monitor data-collection endpoint show --resource-group "rg-sentinel-dev-2" --name "dce-api-ingestion-dev" --query "logsIngestion.endpoint" -o tsv
  [Parameter(Mandatory=$false)] [string]$DcrImmutableId = "dcr-cdb40ceabb6242d5b7d412b04961c24e",  # From: az monitor data-collection rule show --name "dcr-api-security-events-dev" --query "immutableId"
  [string]$StreamName = "Custom-SecurityEvents",  # Updated to match Terraform-created DCR stream declaration
  [string]$InputJsonPath,
  [Object[]]$Events,
  [switch]$Gzip,
  [switch]$ShowBody
)
# Example Usage:
# 1. Create App Registration: az ad app create --display-name "DCR-API-Ingestion-App" --query "appId" -o tsv
# 2. Create Service Principal: az ad sp create --id "[YOUR_AZURE_CLIENT_ID]"  
# 3. Create Client Secret: az ad app credential reset --id "[YOUR_AZURE_CLIENT_ID]" --display-name "DCR-Ingestion-Secret" --query "password" -o tsv
# 4. Create Custom Table: az monitor log-analytics workspace table create --resource-group "rg-sentinel-dev-2" --workspace-name "law-sentinel-dev-2" --name "MinimalLogs_CL" --columns TimeGenerated=datetime Message=string
# 5. Create DCR with Azure CLI (due to Terraform limitations): az monitor data-collection rule create --resource-group "rg-sentinel-dev-2" --name "dcr-api-logs-direct-dev" --rule-file "create-dcr-direct.json"
# 6. Assign Role: az role assignment create --assignee "[YOUR_AZURE_CLIENT_ID]" --role "Monitoring Metrics Publisher" --scope "/subscriptions/[YOUR_AZURE_SUBSCRIPTION_ID]/resourceGroups/rg-sentinel-dev-2"
# 
# Usage Examples:
# .\scripts\post-events.ps1 -ClientSecret $env:AZURE_CLIENT_SECRET -InputJsonPath "scripts\security-events.json" -ShowBody
# .\scripts\post-events.ps1 -ClientSecret $env:AZURE_CLIENT_SECRET -ShowBody  # Uses sample data 

$ErrorActionPreference = "Stop"

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

function Confirm-JsonArray {
  param([string]$JsonText)
  try {
    $obj = $JsonText | ConvertFrom-Json -ErrorAction Stop
    if ($obj -is [System.Array]) { return ($obj | ConvertTo-Json -Depth 64) }
    else { return (@($obj) | ConvertTo-Json -Depth 64) }
  }
  catch {
    throw "Input is not valid JSON. Provide a JSON object or array. $_"
  }
}

function Build-BodyJson {
  param([string]$InputJsonPath, [Object[]]$Events)
  
  # =====================================================================================
  # DYNAMIC JSON FIELD MAPPING SYSTEM FOR AZURE MONITOR CUSTOM TABLES
  # =====================================================================================
  # This function transforms incoming JSON data to match custom table schemas in Azure Monitor.
  # It supports three input methods and provides flexible field mapping for different log types.
  #
  # SUPPORTED INPUT METHODS:
  # 1. File-based: -InputJsonPath parameter reads JSON files and maps fields dynamically
  # 2. Direct events: -Events parameter accepts PowerShell objects for programmatic use  
  # 3. Sample data: Fallback generates sample SecurityEvents_CL data for testing
  #
  # FIELD MAPPING STRATEGY:
  # - Primary check: Common external log field names (lowercase/camelCase)
  # - Secondary check: Microsoft standard field names (PascalCase)
  # - Fallback: Sensible defaults or empty strings for missing data
  #
  # TO CUSTOMIZE FOR DIFFERENT TABLES:
  # 1. Update the hashtable field names to match your target custom table schema
  # 2. Modify the conditional field mappings to check for your expected input field names
  # 3. Update the $StreamName parameter to match your DCR stream declaration
  # 4. Ensure your DCR's dataFlows.outputStream matches the target table name
  #
  # EXAMPLE TABLE SCHEMAS SUPPORTED:
  # - SecurityEvents_CL: Security events with IP addresses, protocols, actions
  # - NetworkLogs_CL: Network traffic with bytes transferred, connection details  
  # - ApplicationLogs_CL: Application logs with levels, hosts, users
  # - ThreatIntelLogs_CL: Threat intelligence indicators with confidence scores
  # =====================================================================================
  
  if ($InputJsonPath) {
    # Handle relative paths from script execution location
    if (-not [System.IO.Path]::IsPathRooted($InputJsonPath)) {
      $InputJsonPath = Join-Path (Get-Location) $InputJsonPath
    }
    
    if (-not (Test-Path $InputJsonPath)) {
      throw "JSON file not found at path: $InputJsonPath"
    }
    
    Write-Host "Reading JSON from: $InputJsonPath" -ForegroundColor Yellow
    $raw = Get-Content -Path $InputJsonPath -Raw -ErrorAction Stop
    $eventsArray = $raw | ConvertFrom-Json
    
    # =====================================================================================
    # JSON FIELD MAPPING CONFIGURATION FOR CUSTOM TABLES
    # =====================================================================================
    # This section maps incoming JSON fields to the target custom table schema.
    # Currently configured for: SecurityEvents_CL
    # 
    # TO MODIFY FOR DIFFERENT LOG TYPES OR TABLES:
    # 1. Update the field mappings below to match your target table schema
    # 2. Change the DCR stream name parameter ($StreamName) to match your DCR configuration
    # 3. Ensure your DCR's streamDeclarations match the output field names
    #
    # COMMON CUSTOM TABLE SCHEMAS AND FIELD MAPPINGS:
    # 
    # For NetworkLogs_CL:
    #   - TimeGenerated → timestamp/TimeGenerated (required datetime field)
    #   - SourceIP → srcIP/sourceIP/src_ip/client_ip
    #   - DestinationIP → destIP/destinationIP/dest_ip/server_ip
    #   - Protocol → protocol/Protocol
    #   - BytesIn → bytes_in/rx_bytes/inbound_bytes
    #   - BytesOut → bytes_out/tx_bytes/outbound_bytes
    #   - Action → action/verdict/disposition
    #
    # For ApplicationLogs_CL:
    #   - TimeGenerated → timestamp/@timestamp/log_time
    #   - Level → level/severity/log_level (INFO/WARN/ERROR/DEBUG)
    #   - Message → message/msg/log_message
    #   - Application → app_name/service/component
    #   - Host → hostname/host/server
    #   - User → user/username/user_id
    #
    # For ThreatIntelLogs_CL:
    #   - TimeGenerated → timestamp/observed_time/first_seen
    #   - Indicator → indicator/ioc/observable
    #   - Type → type/indicator_type (IP/Domain/Hash/URL)
    #   - Confidence → confidence/score/confidence_level
    #   - Source → source/feed/provider
    #   - Tags → tags/labels/categories (array → join with comma)
    #
    # FIELD MAPPING PATTERN EXPLANATION:
    # Each field uses conditional logic: if (source_field) { use_it } elseif (alt_field) { use_alt } else { default }
    # - First condition: checks for common lowercase/camelCase variants from external logs
    # - Second condition: checks for PascalCase variants (standard in many MS logs)
    # - Else clause: provides sensible defaults or empty strings for optional fields
    #
    # Map JSON fields to SecurityEvents_CL schema
    $processedEvents = @()
    foreach ($eventItem in $eventsArray) {
      $processedEvents += @{ 
        # TimeGenerated: Required datetime field (ISO 8601 format recommended)
        # Common source fields: timestamp, @timestamp, eventTime, log_time, occurred_at
        "TimeGenerated" = if ($eventItem.timestamp) { $eventItem.timestamp } elseif ($eventItem.TimeGenerated) { $eventItem.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
        
        # EventType: Categorizes the security event type
        # Common source fields: source, event_type, category, alert_type, log_type
        "EventType" = if ($eventItem.source) { $eventItem.source } elseif ($eventItem.EventType) { $eventItem.EventType } else { "SecurityEvent" }
        
        # SourceIP: Origin IP address of the event
        # Common source fields: sourceIP, src_ip, client_ip, remote_addr, origin_ip
        "SourceIP" = if ($eventItem.sourceIP) { $eventItem.sourceIP } elseif ($eventItem.SourceIP) { $eventItem.SourceIP } else { "" }
        
        # DestinationIP: Target IP address of the event  
        # Common source fields: destinationIP, dest_ip, target_ip, server_ip, local_addr
        "DestinationIP" = if ($eventItem.destinationIP) { $eventItem.destinationIP } elseif ($eventItem.DestinationIP) { $eventItem.DestinationIP } else { "" }
        
        # Protocol: Network protocol used (normalized to uppercase)
        # Common source fields: protocol, proto, transport_protocol, network_protocol
        "Protocol" = if ($eventItem.protocol) { $eventItem.protocol.ToUpper() } elseif ($eventItem.Protocol) { $eventItem.Protocol } else { "" }
        
        # Action: Action taken on the event (Allow/Block/Alert/etc.)
        # Common source fields: action, verdict, disposition, result, outcome
        "Action" = if ($eventItem.action) { $eventItem.action } elseif ($eventItem.Action) { $eventItem.Action } else { "" }
        
        # Severity: Event severity level
        # Common source fields: severity, priority, level, criticality, risk_score
        # Standard values: Low, Medium, High, Critical, Informational
        "Severity" = if ($eventItem.severity) { $eventItem.severity } elseif ($eventItem.Severity) { $eventItem.Severity } else { "Medium" }
        
        # Message: Detailed event description or full JSON fallback
        # Common source fields: message, description, details, summary, raw_log
        "Message" = if ($eventItem.message) { $eventItem.message } elseif ($eventItem.Message) { $eventItem.Message } else { ($eventItem | ConvertTo-Json -Compress) }
      }
    }
    
    return ($processedEvents | ConvertTo-Json -Depth 64 -AsArray)
  }
  elseif ($Events) {
    if ($Events -isnot [System.Array]) { $Events = @($Events) }
    
    # =====================================================================================
    # DIRECT EVENTS PARAMETER MAPPING FOR CUSTOM TABLES
    # =====================================================================================
    # This section handles events passed directly via the -Events parameter.
    # Uses the same field mapping logic as file-based processing above.
    # 
    # USAGE EXAMPLES FOR DIFFERENT TABLE TYPES:
    #
    # For SecurityEvents_CL (current configuration):
    # $events = @(@{TimeGenerated="2024-01-01T12:00:00Z"; EventType="Login"; SourceIP="1.2.3.4"})
    # .\post-events.ps1 -Events $events -ClientSecret "xxx"
    #
    # For NetworkLogs_CL (modify field mappings accordingly):
    # $events = @(@{timestamp="2024-01-01T12:00:00Z"; srcIP="1.2.3.4"; destIP="5.6.7.8"; protocol="TCP"})
    #
    # For ApplicationLogs_CL (modify field mappings accordingly):
    # $events = @(@{log_time="2024-01-01T12:00:00Z"; level="ERROR"; message="Database connection failed"; app_name="WebAPI"})
    #
    # CUSTOMIZATION NOTES:
    # - Update field names in the hashtable below to match your target table schema
    # - Modify the conditional logic to check for your expected input field names
    # - Adjust default values to appropriate defaults for your log type
    # - Ensure the output field names match your DCR's streamDeclarations
    #
    # Convert events to SecurityEvents_CL schema format
    $processedEvents = @()
    foreach ($eventItem in $Events) {
      $processedEvents += @{ 
        # Required datetime field - uses current time if not provided
        "TimeGenerated" = if ($eventItem.TimeGenerated) { $eventItem.TimeGenerated } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
        
        # Event categorization with fallback default
        "EventType" = if ($eventItem.EventType) { $eventItem.EventType } else { "SecurityEvent" }
        
        # Network source information with example default
        "SourceIP" = if ($eventItem.SourceIP) { $eventItem.SourceIP } else { "192.168.1.100" }
        
        # Network destination information with example default
        "DestinationIP" = if ($eventItem.DestinationIP) { $eventItem.DestinationIP } else { "10.0.0.1" }
        
        # Protocol information with common default
        "Protocol" = if ($eventItem.Protocol) { $eventItem.Protocol } else { "HTTPS" }
        
        # Action result with common default
        "Action" = if ($eventItem.Action) { $eventItem.Action } else { "Allow" }
        
        # Severity level with moderate default
        "Severity" = if ($eventItem.Severity) { $eventItem.Severity } else { "Medium" }
        
        # Event details with JSON serialization fallback
        "Message" = if ($eventItem.Message) { $eventItem.Message } else { ($eventItem | ConvertTo-Json -Compress) }
      }
    }
    return ($processedEvents | ConvertTo-Json -Depth 64 -AsArray)
  }
  else {
    # Fallback sample payload matching SecurityEvents_CL schema
    $sample = @(
      @{ 
        "TimeGenerated" = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        "EventType" = "Login"
        "SourceIP" = "203.0.113.45"
        "DestinationIP" = "10.0.0.100"
        "Protocol" = "HTTPS"
        "Action" = "Allow"
        "Severity" = "High"
        "Message" = "Successful login from PowerShell script - user: $env:USERNAME"
      }
    )
    return ($sample | ConvertTo-Json -Depth 64 -AsArray)
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

# Build target URI
$uri = "$DceBaseUrl/dataCollectionRules/$DcrImmutableId/streams/$StreamName" + "?api-version=2023-01-01"
Write-Host "Posting to: $uri" -ForegroundColor Cyan

# Acquire token
Write-Host "Acquiring OAuth token..." -ForegroundColor Yellow
$token = Get-OAuthToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

# Build body
$bodyJson = Build-BodyJson -InputJsonPath $InputJsonPath -Events $Events

if ($ShowBody) {
  Write-Host "Request body:" -ForegroundColor Magenta
  Write-Host $bodyJson -ForegroundColor Gray
}

# Prepare request
$headers = @{ 
  Authorization = "Bearer $token"
  'Content-Type' = 'application/json'
}

try {
  if ($Gzip) {
    Write-Host "Compressing payload with gzip..." -ForegroundColor Yellow
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)
    $gz    = Compress-GzipBytes -Bytes $bytes
    $headers['Content-Encoding'] = 'gzip'
    $resp = Invoke-WebRequest -Method Post -Uri $uri -Headers $headers -Body $gz -UseBasicParsing
  }
  else {
    $resp = Invoke-WebRequest -Method Post -Uri $uri -Headers $headers -Body $bodyJson -UseBasicParsing
  }

  if ($resp.StatusCode -in 200, 202, 204) {
    Write-Host "✅ Success: HTTP $($resp.StatusCode)" -ForegroundColor Green
    if ($ShowBody -and $resp.Content) { 
      Write-Host "Response: $($resp.Content)" -ForegroundColor Gray 
    }
  } else {
    Write-Host "⚠️  Warning: HTTP $($resp.StatusCode)" -ForegroundColor Yellow
    if ($resp.Content) { 
      Write-Host "Response: $($resp.Content)" -ForegroundColor Red 
    }
  }
}
catch {
  Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
  if ($_.Exception.Response) {
    try {
      $errorStream = $_.Exception.Response.Content.ReadAsStringAsync().Result
      Write-Host "Error details: $errorStream" -ForegroundColor Red
    }
    catch {
      Write-Host "Could not read error response details" -ForegroundColor Red
    }
  }
  throw
}