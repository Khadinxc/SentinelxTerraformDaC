# Enhanced Azure Sentinel Export Script
# Exports all content types: Analytics Rules

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "99e4678b-b904-4c08-8779-7e9f99b17073",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-sentinel-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceName = "law-sentinel-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputBaseDir = "Detections",
    
    [Parameter(Mandatory=$false)]
    [string[]]$ContentTypes = @("AnalyticsRules")
)

# Configuration
$baseUri = "https://management.azure.com"
$token = (az account get-access-token --resource https://management.azure.com --query accessToken -o tsv).Trim()
$headers = @{ 
    Authorization = "Bearer $token"
    'Content-Type' = 'application/json'
}

# Content type configurations based on deployment script analysis
$contentConfig = @{
    "AnalyticsRules" = @{
        Endpoint = "$baseUri/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/alertRules"
        ApiVersion = "2022-11-01"
        OutputDir = "$OutputBaseDir/Analytics Rules"
        FilePrefix = ""
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info" { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Export-ContentType {
    param(
        [string]$ContentTypeName,
        [hashtable]$Config
    )
    
    Write-Log "Starting export for $ContentTypeName..." -Level "Info"
    
    try {
        # Ensure output directory exists
        if (-not (Test-Path $Config.OutputDir)) {
            New-Item -ItemType Directory -Path $Config.OutputDir -Force | Out-Null
            Write-Log "Created directory: $($Config.OutputDir)" -Level "Info"
        }
        
        # Build API URI
        $uri = "$($Config.Endpoint)?api-version=$($Config.ApiVersion)"
        Write-Log "Calling API: $uri" -Level "Info"
        
        # Make API call
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
        
        if (-not $response.value) {
            Write-Log "No items found for $ContentTypeName" -Level "Warning"
            return 0
        }
        
        # Apply filter if specified
        $items = $response.value
        if ($Config.Filter) {
            $items = $items | Where-Object $Config.Filter
        }
        
        if ($items.Count -eq 0) {
            Write-Log "No items found after filtering for $ContentTypeName" -Level "Warning"
            return 0
        }
        
        $exportCount = 0
        $items | ForEach-Object {
            try {
                # Generate filename based on content type
                $filename = switch ($ContentTypeName) {
                    "AnalyticsRules" { 
                        if ($_.properties.displayName) {
                            ($_.properties.displayName -replace '[<>:"/\\|?*]', '_').Trim()
                        } else {
                            $_.name
                        }
                    }
                    "AutomationRules" {
                        if ($_.properties.displayName) {
                            ($_.properties.displayName -replace '[<>:"/\\|?*]', '_').Trim()
                        } else {
                            $_.name
                        }
                    }
                    "HuntingQueries" {
                        if ($_.properties.DisplayName) {
                            ($_.properties.DisplayName -replace '[<>:"/\\|?*]', '_').Trim()
                        } else {
                            $_.name
                        }
                    }
                    "Parsers" {
                        if ($_.properties.FunctionAlias) {
                            $_.properties.FunctionAlias
                        } elseif ($_.properties.DisplayName) {
                            ($_.properties.DisplayName -replace '[<>:"/\\|?*]', '_').Trim()
                        } else {
                            $_.name
                        }
                    }
                    "Playbooks" {
                        if ($_.name) {
                            $_.name
                        } else {
                            "playbook_$($_.id.Split('/')[-1])"
                        }
                    }
                    "Workbooks" {
                        if ($_.properties.displayName) {
                            ($_.properties.displayName -replace '[<>:"/\\|?*]', '_').Trim()
                        } else {
                            $_.name
                        }
                    }
                    default { $_.name }
                }
                
                # Ensure filename is not empty and add GUID as fallback
                if ([string]::IsNullOrWhiteSpace($filename)) {
                    $filename = $_.name
                }
                
                $outputPath = Join-Path $Config.OutputDir "$filename.json"
                
                # Convert to JSON and save
                $_ | ConvertTo-Json -Depth 20 | Out-File $outputPath -Encoding UTF8
                
                Write-Log "Exported: $filename.json" -Level "Success"
                $exportCount++
                
            } catch {
                Write-Log "Failed to export item: $($_.Exception.Message)" -Level "Error"
            }
        }
        
        Write-Log "Completed export for $ContentTypeName - $exportCount items exported" -Level "Success"
        return $exportCount
        
    } catch {
        Write-Log "Failed to export $ContentTypeName`: $($_.Exception.Message)" -Level "Error"
        return 0
    }
}

# Main execution
Write-Log "Starting Azure Sentinel content export..." -Level "Info"
Write-Log "Subscription: $SubscriptionId" -Level "Info"
Write-Log "Resource Group: $ResourceGroup" -Level "Info"
Write-Log "Workspace: $WorkspaceName" -Level "Info"
Write-Log "Output Directory: $OutputBaseDir" -Level "Info"
Write-Log "Content Types: $($ContentTypes -join ', ')" -Level "Info"

$totalExported = 0
$exportSummary = @{}

foreach ($contentType in $ContentTypes) {
    if ($contentConfig.ContainsKey($contentType)) {
        $count = Export-ContentType -ContentTypeName $contentType -Config $contentConfig[$contentType]
        $exportSummary[$contentType] = $count
        $totalExported += $count
    } else {
        Write-Log "Unknown content type: $contentType" -Level "Warning"
    }
}

# Summary
Write-Log "`n=== Export Summary ===" -Level "Info"
foreach ($item in $exportSummary.GetEnumerator()) {
    Write-Log "$($item.Key): $($item.Value) items" -Level "Info"
}
Write-Log "Total exported: $totalExported items" -Level "Success"
Write-Log "Export completed successfully!" -Level "Success"
