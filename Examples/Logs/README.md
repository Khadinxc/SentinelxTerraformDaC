# ASIM Sample Log Files

This directory contains sample log files for testing each ASIM (Advanced Security Information Model) schema supported by our `post-events-to-dce-asim.ps1` script.

## Available Sample Files

### 1. Network Session Logs (`network-session-sample.json`)
- **Schema**: NetworkSession
- **Sample Events**: 3 events
- **Content**: Firewall traffic logs, network connections, blocked/allowed traffic
- **Test Command**:
  ```powershell
  .\scripts\post-events-to-dce-asim.ps1 -AsimSchema "NetworkSession" -InputJsonPath "Examples\Logs\network-session-sample.json" -ValidateOnly -ShowBody
  ```

### 2. DNS Activity Logs (`dns-activity-sample.json`)
- **Schema**: DnsActivity  
- **Sample Events**: 4 events
- **Content**: DNS queries, responses, blocked/allowed domains, various record types
- **Test Command**:
  ```powershell
  .\scripts\post-events-to-dce-asim.ps1 -AsimSchema "DnsActivity" -InputJsonPath "Examples\Logs\dns-activity-sample.json" -ValidateOnly -ShowBody
  ```

### 3. Authentication Events (`authentication-sample.json`)
- **Schema**: Authentication
- **Sample Events**: 5 events
- **Content**: Login attempts, successful/failed authentication, various logon types
- **Test Command**:
  ```powershell
  .\scripts\post-events-to-dce-asim.ps1 -AsimSchema "Authentication" -InputJsonPath "Examples\Logs\authentication-sample.json" -ValidateOnly -ShowBody
  ```

### 4. Process Events (`process-event-sample.json`)
- **Schema**: ProcessEvent
- **Sample Events**: 4 events
- **Content**: Process creation, suspicious executables, command lines, parent processes
- **Test Command**:
  ```powershell
  .\scripts\post-events-to-dce-asim.ps1 -AsimSchema "ProcessEvent" -InputJsonPath "Examples\Logs\process-event-sample.json" -ValidateOnly -ShowBody
  ```

### 5. File Events (`file-event-sample.json`)
- **Schema**: FileEvent
- **Sample Events**: 5 events
- **Content**: File creation, access, modification, deletion with hashes
- **Test Command**:
  ```powershell
  .\scripts\post-events-to-dce-asim.ps1 -AsimSchema "FileEvent" -InputJsonPath "Examples\Logs\file-event-sample.json" -ValidateOnly -ShowBody
  ```

### 6. Registry Events (`registry-event-sample.json`)
- **Schema**: RegistryEvent
- **Sample Events**: 5 events
- **Content**: Registry key/value modifications, Windows-specific events
- **Test Command**:
  ```powershell
  .\scripts\post-events-to-dce-asim.ps1 -AsimSchema "RegistryEvent" -InputJsonPath "Examples\Logs\registry-event-sample.json" -ValidateOnly -ShowBody
  ```

### 7. Web Session Logs (`web-session-sample.json`)
- **Schema**: WebSession
- **Sample Events**: 5 events
- **Content**: HTTP requests, web traffic, proxy logs, status codes
- **Test Command**:
  ```powershell
  .\scripts\post-events-to-dce-asim.ps1 -AsimSchema "WebSession" -InputJsonPath "Examples\Logs\web-session-sample.json" -ValidateOnly -ShowBody
  ```

### 8. Audit Events (`audit-event-sample.json`)
- **Schema**: AuditEvent
- **Sample Events**: 5 events
- **Content**: Policy changes, user account modifications, configuration changes
- **Test Command**:
  ```powershell
  .\scripts\post-events-to-dce-asim.ps1 -AsimSchema "AuditEvent" -InputJsonPath "Examples\Logs\audit-event-sample.json" -ValidateOnly -ShowBody
  ```

## Testing Workflow

### 1. Validation Testing (Recommended First Step)
Test field mappings without sending data to DCE:
```powershell
# Test all schemas with validation
.\scripts\post-events-to-dce-asim.ps1 -AsimSchema "NetworkSession" -InputJsonPath "Examples\Logs\network-session-sample.json" -ValidateOnly -ShowBody
.\scripts\post-events-to-dce-asim.ps1 -AsimSchema "DnsActivity" -InputJsonPath "Examples\Logs\dns-activity-sample.json" -ValidateOnly -ShowBody
.\scripts\post-events-to-dce-asim.ps1 -AsimSchema "Authentication" -InputJsonPath "Examples\Logs\authentication-sample.json" -ValidateOnly -ShowBody
# ... continue for all schemas
```

### 2. Live Data Ingestion
After validation, send data to your DCE (requires valid ClientSecret):
```powershell
.\scripts\post-events-to-dce-asim.ps1 -AsimSchema "NetworkSession" -InputJsonPath "Examples\Logs\network-session-sample.json" -ClientSecret "your-secret-here" -ShowBody
```

### 3. Batch Testing Script
Create a simple batch test script:
```powershell
# test-all-asim-schemas.ps1
$schemas = @("NetworkSession", "DnsActivity", "Authentication", "ProcessEvent", "FileEvent", "RegistryEvent", "WebSession", "AuditEvent")

foreach ($schema in $schemas) {
    Write-Host "Testing ASIM Schema: $schema" -ForegroundColor Cyan
    $fileName = $schema.ToLower() -replace "session|activity|event", ""
    if ($schema -eq "NetworkSession") { $fileName = "network-session" }
    elseif ($schema -eq "DnsActivity") { $fileName = "dns-activity" }
    else { $fileName = $schema.ToLower() -replace "event$", "-event" }
    
    $filePath = "Examples\Logs\$fileName-sample.json"
    .\scripts\post-events-to-dce-asim.ps1 -AsimSchema $schema -InputJsonPath $filePath -ValidateOnly
    Write-Host ""
}
```

## Sample Data Features

Each sample file includes:
- **Realistic Field Variations**: Tests the script's ability to map different field name formats
- **Multiple Vendors**: Includes logs from various security vendors (Microsoft, Cisco, Fortinet, etc.)
- **Severity Levels**: Different event severity levels (Informational, Medium, High, Critical)
- **Complete Coverage**: Tests both required and optional ASIM fields
- **Edge Cases**: Includes malicious activity, failed attempts, and security events

## Field Mapping Testing

The sample files are designed to test the field mapping logic in our script:
- **Primary Field Names**: Common lowercase/camelCase variants (`src_ip`, `timestamp`)
- **Secondary Field Names**: Microsoft PascalCase variants (`SourceIP`, `TimeGenerated`)  
- **Fallback Values**: Events with missing fields to test default value assignment
- **Data Type Validation**: Proper data types for ports (integers), IPs (strings), timestamps (ISO 8601)

## Customization

To create your own test files:
1. Copy one of the existing sample files
2. Modify the field names to match your log source format
3. Test with `-ValidateOnly` flag first
4. Adjust field mappings in the script if needed

## Troubleshooting

If validation fails:
1. Check that all required fields for the ASIM schema are present
2. Verify JSON syntax is valid
3. Ensure timestamp fields are in ISO 8601 format
4. Review the field mapping functions in the script for your specific field names
