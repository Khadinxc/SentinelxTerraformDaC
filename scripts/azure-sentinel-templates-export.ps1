<#
.SYNOPSIS
    Export Analytics Rules from Microsoft Sentinel to JSON files.
    Pipeline version with environment variable authentication.
#>

param (
    [string]$subscriptionId = $env:subscriptionId,
    [string]$resourceGroup = $env:resourceGroup,
    [string]$workspaceName = $env:workspaceName,
    [string]$analyticsApiVersion = "2023-11-01-preview",
    [string]$stableApiVersion = "2023-09-01"
)

Write-Host "🚀 Starting Sentinel Templates Export (Pipeline Version)..." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# ✅ Acquire token via az CLI and remove trailing newline/whitespace
Write-Host "🔑 Acquiring access token..." -ForegroundColor Yellow
try {
    $accessToken = (az account get-access-token --resource https://management.azure.com --query accessToken -o tsv).Trim()
    Write-Host "✅ Access token acquired successfully" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to acquire access token: $_"
    exit 1
}

function Export-SentinelTemplates {
    param (
        [string]$accessToken,
        [string]$resourceType,
        [string]$apiPath,
        [string]$baseOutputDir = ".\templates\ARM",
        [string]$apiVersion = "2023-09-01"
    )

    Write-Host "`n📤 Exporting $resourceType templates..."

    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName/providers/Microsoft.SecurityInsights/" + $apiPath + "?api-version=$apiVersion"
    
    Write-Host "🔧 URI: $uri"
    Write-Host "📌 API Path: $apiPath"
    Write-Host "📌 API Version: $apiVersion"

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers @{ Authorization = "Bearer $accessToken" }
        Write-Host "✅ API call successful!" -ForegroundColor Green
    } catch {
        Write-Warning "❌ Failed to fetch $resourceType`: $_"
        return @{ Success = $false; Exported = 0; Skipped = 0 }
    }

    if (-not $response.value) {
        Write-Warning "⚠️ No templates found for $resourceType"
        return @{ Success = $true; Exported = 0; Skipped = 0 }
    }

    # Initialize counters for different rule types
    $exportedCount = 0
    $skippedCount = 0
    $ruleTypeCounts = @{
        "Scheduled" = 0
        "Fusion" = 0
        "MicrosoftSecurityIncidentCreation" = 0
        "MLBehaviorAnalytics" = 0
        "NRT" = 0
        "Other" = 0
    }

    foreach ($item in $response.value) {
        $name = $item.name
        $displayName = ""
        $ruleKind = $item.kind

        # Get display name from properties or root level
        if ($item.properties -and $item.properties.displayName) {
            $displayName = $item.properties.displayName
        } elseif ($item.displayName) {
            $displayName = $item.displayName
        }

        # Check if template is deprecated
        if ($displayName -match "(?i)\[deprecated\]|deprecated") {
            Write-Host "⚠️ Skipping deprecated template: $displayName" -ForegroundColor Yellow
            $skippedCount++
            continue
        }

        # Determine the output directory based on resource type and rule kind
        $outputDir = ""
        
        if ($resourceType -eq "Analytics Rules") {
            # For Analytics Rules, organize by rule kind
            switch ($ruleKind) {
                "Scheduled" { 
                    $outputDir = Join-Path $baseOutputDir "ScheduledRules"
                    $ruleTypeCounts["Scheduled"]++
                }
                "Fusion" { 
                    $outputDir = Join-Path $baseOutputDir "FusionRules"
                    $ruleTypeCounts["Fusion"]++
                }
                "MicrosoftSecurityIncidentCreation" { 
                    $outputDir = Join-Path $baseOutputDir "MicrosoftRules"
                    $ruleTypeCounts["MicrosoftSecurityIncidentCreation"]++
                }
                "MLBehaviorAnalytics" { 
                    $outputDir = Join-Path $baseOutputDir "MLBehaviorAnalyticsRules"
                    $ruleTypeCounts["MLBehaviorAnalytics"]++
                }
                "NRT" { 
                    $outputDir = Join-Path $baseOutputDir "NRTRules"
                    $ruleTypeCounts["NRT"]++
                }
                default { 
                    $outputDir = Join-Path $baseOutputDir "AnalyticsRules"
                    $ruleTypeCounts["Other"]++
                    Write-Host "⚠️ Unknown rule kind '$ruleKind' for template: $displayName" -ForegroundColor Yellow
                }
            }
        } else {
            # For other resource types, create simple folders
            switch ($resourceType) {
                "Hunting Queries" { $outputDir = Join-Path $baseOutputDir "HuntingQueries" }
                "Workbooks" { $outputDir = Join-Path $baseOutputDir "Workbooks" }
                "Watchlists" { $outputDir = Join-Path $baseOutputDir "Watchlists" }
                "Playbooks" { $outputDir = Join-Path $baseOutputDir "Playbooks" }
                default { $outputDir = Join-Path $baseOutputDir $resourceType.Replace(" ", "") }
            }
        }

        # Create directory if it doesn't exist
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Export the template
        $json = $item | ConvertTo-Json -Depth 10
        $filePath = Join-Path $outputDir "$name.json"
        $json | Out-File -FilePath $filePath -Encoding utf8
        Write-Host "✅ Exported [$ruleKind] $name -> $filePath"
        $exportedCount++
    }
    
    Write-Host "📊 Summary for $resourceType templates:" -ForegroundColor Cyan
    Write-Host "   ✅ Total Exported: $exportedCount" -ForegroundColor Green
    Write-Host "   ⚠️  Total Skipped (deprecated): $skippedCount" -ForegroundColor Yellow
    Write-Host "📊 Breakdown by Rule Type:" -ForegroundColor Cyan
    foreach ($ruleType in $ruleTypeCounts.Keys) {
        if ($ruleTypeCounts[$ruleType] -gt 0) {
            Write-Host "   📁 $ruleType`: $($ruleTypeCounts[$ruleType])" -ForegroundColor White
        }
    }
    
    # Return result object for final summary
    return @{ Success = $true; Exported = $exportedCount; Skipped = $skippedCount; RuleTypeCounts = $ruleTypeCounts }
}

# ---- Script Entry Point ----
Write-Host "`n🏁 Starting export process..." -ForegroundColor Cyan

# Paths - Use relative path for pipeline compatibility
$templatesRoot = Join-Path $PSScriptRoot "..\templates\ARM"
Write-Host "� Templates will be exported to: $templatesRoot" -ForegroundColor Yellow

# Ensure the base directory exists
if (-not (Test-Path $templatesRoot)) {
    New-Item -ItemType Directory -Path $templatesRoot -Force | Out-Null
    Write-Host "✅ Created base templates directory" -ForegroundColor Green
}

$results = @{}

# Export different types of Sentinel content
Write-Host "`n📋 Exporting Sentinel content..." -ForegroundColor Cyan

# Export Analytics Rule Templates
$results.Analytics = Export-SentinelTemplates -accessToken $accessToken -resourceType "Analytics Rules" -apiPath "alertRuleTemplates" -baseOutputDir $templatesRoot -apiVersion $analyticsApiVersion

# Final summary
Write-Host "`n🎉 Export completed!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "📊 Final Summary:" -ForegroundColor Cyan
foreach ($key in $results.Keys) {
    $result = $results[$key]
    if ($result -and $result.Success) {
        Write-Host "   $key`: ✅ $($result.Exported) exported, ⚠️ $($result.Skipped) skipped" -ForegroundColor White
        if ($result.RuleTypeCounts) {
            Write-Host "      📁 Rule Type Distribution:" -ForegroundColor Gray
            foreach ($ruleType in $result.RuleTypeCounts.Keys) {
                if ($result.RuleTypeCounts[$ruleType] -gt 0) {
                    $folderName = switch ($ruleType) {
                        "Scheduled" { "ScheduledRules" }
                        "Fusion" { "FusionRules" }
                        "MicrosoftSecurityIncidentCreation" { "MicrosoftRules" }
                        "MLBehaviorAnalytics" { "MLBehaviorAnalyticsRules" }
                        "NRT" { "NRTRules" }
                        default { "AnalyticsRules" }
                    }
                    Write-Host "         -> $folderName`: $($result.RuleTypeCounts[$ruleType])" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "   $key`: ❌ Failed" -ForegroundColor Red
    }
}