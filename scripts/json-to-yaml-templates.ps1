# json-to-yaml-templates.ps1
# Converts exported Sentinel template JSON files to YAML with human-readable filenames
# Dynamically processes all rule type folders in the ARM templates directory
# Output: YAMLTemplates/ - Exported templates ready for Terraform ingestion

Write-Host "🚀 Starting JSON to YAML conversion for all discovered rule types..." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "📦 Installing powershell-yaml module..." -ForegroundColor Yellow
    Install-Module powershell-yaml -Force -Scope CurrentUser
}
Import-Module powershell-yaml

function Format-FileName {
    param([string]$Name)
    
    # Remove invalid filename characters and clean up
    $cleanName = $Name -replace '[<>:"/\\|?*]', '_'  # Replace invalid chars with underscore
    $cleanName = $cleanName -replace '\s+', ' '      # Normalize whitespace
    $cleanName = $cleanName.Trim()                   # Remove leading/trailing spaces
    $cleanName = $cleanName -replace '\s', '_'       # Replace spaces with underscores
    $cleanName = $cleanName -replace '_+', '_'       # Remove duplicate underscores
    
    # Truncate if too long (Windows has 260 char path limit)
    if ($cleanName.Length -gt 200) {
        $cleanName = $cleanName.Substring(0, 200)
    }
    return $cleanName
}

# Dynamically discover all template directories in the ARM folder
$armTemplatesPath = Join-Path $PSScriptRoot "..\templates\ARM"
if (-not (Test-Path $armTemplatesPath)) {
    Write-Error "❌ ARM templates directory not found: $armTemplatesPath"
    Write-Host "💡 Please run the export script first to generate ARM templates" -ForegroundColor Yellow
    exit 1
}

Write-Host "📁 Discovering template directories in: $armTemplatesPath" -ForegroundColor Yellow
$templateDirs = Get-ChildItem -Path $armTemplatesPath -Directory | ForEach-Object { $_.Name } | Sort-Object
Write-Host "🔍 Found $($templateDirs.Count) template directories: $($templateDirs -join ', ')" -ForegroundColor Green

# Create YAML output base directory
$yamlOutputBasePath = Join-Path $PSScriptRoot "..\templates\YAML\"
if (-not (Test-Path $yamlOutputBasePath)) {
    New-Item -ItemType Directory -Path $yamlOutputBasePath -Force | Out-Null
    Write-Host "✅ Created YAML output directory: $yamlOutputBasePath" -ForegroundColor Green
}

$totalConverted = 0
$totalFailed = 0
$kindCounts = @{}

# Process all JSON files from all ARM directories and organize by kind
foreach ($subdir in $templateDirs) {
    $inputDir  = Join-Path $armTemplatesPath $subdir

    # Check if input directory exists and has files
    if (-not (Test-Path $inputDir)) {
        Write-Host "⚠️  Skipping $subdir - input directory not found: $inputDir" -ForegroundColor Yellow
        continue
    }
    
    $jsonFiles = Get-ChildItem -Path $inputDir -Filter *.json
    if ($jsonFiles.Count -eq 0) {
        Write-Host "⚠️  Skipping $subdir - no JSON files found" -ForegroundColor Yellow
        continue
    }

    Write-Host "`n📂 Processing $subdir folder ($($jsonFiles.Count) files)..." -ForegroundColor Cyan

    $jsonFiles | ForEach-Object {
        $jsonPath  = $_.FullName
        $baseName  = $_.BaseName

        try {
            # Convert JSON to PowerShell object first
            $jsonContent = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json

            # Determine rule kind
            $kind = $null
            if ($jsonContent.kind) { 
                $kind = $jsonContent.kind 
            } else {
                Write-Host "⚠️  No kind found for $baseName, skipping" -ForegroundColor Yellow
                return
            }

            # Create output directory for this kind
            $kindOutputDir = Join-Path $yamlOutputBasePath $kind
            if (-not (Test-Path $kindOutputDir)) {
                New-Item -ItemType Directory -Force -Path $kindOutputDir | Out-Null
                Write-Host "✅ Created directory for $kind rules: $kindOutputDir" -ForegroundColor Green
            }

            # --- Inject required fields if missing ---
            if ($jsonContent.properties) {
                # Ensure 'enabled' property is present for all rule types
                if (-not $jsonContent.properties.PSObject.Properties["enabled"]) {
                    $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "enabled" -Value $true
                }
                
                # Fusion: alertRuleTemplateName
                if ($kind -eq "Fusion" -and -not $jsonContent.properties.PSObject.Properties["alertRuleTemplateName"]) {
                    $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "alertRuleTemplateName" -Value ($jsonContent.name ? $jsonContent.name : "custom-fusion-template")
                }
                
                # MLBehaviorAnalytics: queryFrequency, queryPeriod, triggerOperator
                if ($kind -eq "MLBehaviorAnalytics") {
                    if (-not $jsonContent.properties.PSObject.Properties["queryFrequency"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "queryFrequency" -Value "PT1H"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["queryPeriod"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "queryPeriod" -Value "PT1H"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["triggerOperator"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "triggerOperator" -Value "GreaterThan"
                    }
                }
                
                # Scheduled: suppressionDuration and suppressionEnabled
                if ($kind -eq "Scheduled") {
                    if (-not $jsonContent.properties.PSObject.Properties["suppressionDuration"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "suppressionDuration" -Value "PT1H"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["suppressionEnabled"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "suppressionEnabled" -Value $false
                    }
                }
                
                # NRT: Add required fields for NRT rules
                if ($kind -eq "NRT") {
                    if (-not $jsonContent.properties.PSObject.Properties["queryFrequency"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "queryFrequency" -Value "PT1M"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["queryPeriod"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "queryPeriod" -Value "PT1M"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["triggerOperator"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "triggerOperator" -Value "GreaterThan"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["triggerThreshold"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "triggerThreshold" -Value 0
                    }
                }
                
                # ThreatIntelligence: Add required fields for ThreatIntelligence rules
                if ($kind -eq "ThreatIntelligence") {
                    if (-not $jsonContent.properties.PSObject.Properties["queryFrequency"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "queryFrequency" -Value "PT1H"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["queryPeriod"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "queryPeriod" -Value "PT1H"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["triggerOperator"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "triggerOperator" -Value "GreaterThan"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["triggerThreshold"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "triggerThreshold" -Value 0
                    }
                }
                
                # Microsoft: No special fields needed (inherits from template)
                
                # Add common query fields for rules that have queries but missing timing fields
                if ($jsonContent.properties.query) {
                    if (-not $jsonContent.properties.PSObject.Properties["queryFrequency"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "queryFrequency" -Value "PT1H"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["queryPeriod"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "queryPeriod" -Value "PT1H"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["triggerOperator"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "triggerOperator" -Value "GreaterThan"
                    }
                    if (-not $jsonContent.properties.PSObject.Properties["triggerThreshold"]) {
                        $jsonContent.properties | Add-Member -MemberType NoteProperty -Name "triggerThreshold" -Value 0
                    }
                }
            }

            # Extract display name for filename
            $displayName = $null
            if ($jsonContent.properties -and $jsonContent.properties.displayName) {
                $displayName = $jsonContent.properties.displayName
            } elseif ($jsonContent.displayName) {
                $displayName = $jsonContent.displayName
            }

            # Use display name if available, otherwise fall back to original name
            if ($displayName -and $displayName.Trim() -ne "") {
                $fileName = Format-FileName -Name $displayName
                Write-Host "📝 [$kind] Using display name: '$displayName' → '$fileName'"
            } else {
                $fileName = $baseName
                Write-Host "⚠️  [$kind] No display name found, using original: '$fileName'"
            }

            $yamlPath = Join-Path $kindOutputDir "$fileName.yaml"

            # Transform to Terraform-compatible structure - only extract supported fields
            $terraformCompatible = @{}
            
            if ($jsonContent.properties) {
                $props = $jsonContent.properties
                
                # Core required fields (always include if present)
                if ($props.displayName) { $terraformCompatible.display_name = $props.displayName }
                if ($props.description) { $terraformCompatible.description = $props.description }
                if ($props.severity) { $terraformCompatible.severity = $props.severity }
                if ($props.PSObject.Properties["enabled"]) { $terraformCompatible.enabled = $props.enabled }
                if ($props.query) { $terraformCompatible.query = $props.query }
                
                # Query timing fields (camelCase → snake_case)
                if ($props.queryFrequency) { $terraformCompatible.query_frequency = $props.queryFrequency }
                if ($props.queryPeriod) { $terraformCompatible.query_period = $props.queryPeriod }
                if ($props.triggerOperator) { $terraformCompatible.trigger_operator = $props.triggerOperator }
                if ($props.PSObject.Properties["triggerThreshold"]) { $terraformCompatible.trigger_threshold = $props.triggerThreshold }
                
                # Suppression fields (camelCase → snake_case)
                if ($props.PSObject.Properties["suppressionEnabled"]) { $terraformCompatible.suppression_enabled = $props.suppressionEnabled }
                if ($props.suppressionDuration) { $terraformCompatible.suppression_duration = $props.suppressionDuration }
                
                # MITRE ATT&CK fields
                if ($props.tactics) { $terraformCompatible.tactics = $props.tactics }
                if ($props.techniques) { $terraformCompatible.techniques = $props.techniques }
                
                # Template reference fields
                if ($props.alertRuleTemplateName) { 
                    $terraformCompatible.alert_rule_template_guid = $props.alertRuleTemplateName 
                    # Only include version if we have a template name
                    if ($props.version) { $terraformCompatible.alert_rule_template_version = $props.version }
                }
                
                # Custom details (camelCase → snake_case)
                if ($props.customDetails) { $terraformCompatible.custom_details = $props.customDetails }
                
                # Entity mappings (camelCase → snake_case)
                if ($props.entityMappings) {
                    $terraformCompatible.entity_mappings = @()
                    foreach ($mapping in $props.entityMappings) {
                        $terraformMapping = @{
                            entity_type = $mapping.entityType
                            field_mappings = @()
                        }
                        if ($mapping.fieldMappings) {
                            foreach ($fieldMapping in $mapping.fieldMappings) {
                                $terraformMapping.field_mappings += @{
                                    identifier = $fieldMapping.identifier
                                    column_name = $fieldMapping.columnName
                                }
                            }
                        }
                        $terraformCompatible.entity_mappings += $terraformMapping
                    }
                }
                
                # Event grouping (fix aggregationKind → aggregation_method)
                if ($props.eventGroupingSettings) {
                    $terraformCompatible.event_grouping = @{
                        aggregation_method = switch ($props.eventGroupingSettings.aggregationKind) {
                            "AlertPerResult" { "AlertPerResult" }
                            "SingleAlert" { "SingleAlert" }
                            default { "SingleAlert" }
                        }
                    }
                }
                
                # Alert details override (fix field names)
                if ($props.alertDetailsOverride) {
                    $override = $props.alertDetailsOverride
                    $terraformCompatible.alert_details_override = @{}
                    if ($override.alertDisplayNameFormat) { $terraformCompatible.alert_details_override.display_name_format = $override.alertDisplayNameFormat }
                    if ($override.alertDescriptionFormat) { $terraformCompatible.alert_details_override.description_format = $override.alertDescriptionFormat }
                    if ($override.alertSeverityColumnName) { $terraformCompatible.alert_details_override.severity_column_name = $override.alertSeverityColumnName }
                    if ($override.alertTacticsColumnName) { $terraformCompatible.alert_details_override.tactics_column_name = $override.alertTacticsColumnName }
                }
                
                # Incident configuration (if present)
                if ($props.incidentConfiguration) {
                    $incident = $props.incidentConfiguration
                    $terraformCompatible.incident_configuration = @{}
                    if ($incident.PSObject.Properties["createIncident"]) { $terraformCompatible.incident_configuration.create_incident = $incident.createIncident }
                    if ($incident.groupingConfiguration) {
                        $terraformCompatible.incident_configuration.grouping_enabled = $incident.groupingConfiguration.enabled
                        if ($incident.groupingConfiguration.lookbackDuration) { $terraformCompatible.incident_configuration.lookback_duration = $incident.groupingConfiguration.lookbackDuration }
                        if ($incident.groupingConfiguration.matchingMethod) { $terraformCompatible.incident_configuration.entity_matching_method = $incident.groupingConfiguration.matchingMethod }
                        if ($incident.groupingConfiguration.groupByEntities) { $terraformCompatible.incident_configuration.group_by_entities = $incident.groupingConfiguration.groupByEntities }
                        if ($incident.groupingConfiguration.groupByAlertDetails) { $terraformCompatible.incident_configuration.group_by_alert_details = $incident.groupingConfiguration.groupByAlertDetails }
                        if ($incident.groupingConfiguration.groupByCustomDetails) { $terraformCompatible.incident_configuration.group_by_custom_details = $incident.groupingConfiguration.groupByCustomDetails }
                    }
                }
            }

            # Convert to YAML and save
            $yaml = ConvertTo-Yaml $terraformCompatible
            Set-Content -Path $yamlPath -Value $yaml -Encoding utf8

            Write-Host "✅ Converted $baseName → $kind/$fileName.yaml"
            $totalConverted++
            
            # Track counts by kind
            if (-not $kindCounts.ContainsKey($kind)) {
                $kindCounts[$kind] = @{ Converted = 0; Failed = 0 }
            }
            $kindCounts[$kind].Converted++
        }
        catch {
            Write-Warning "❌ Failed to convert $jsonPath`: $_"
            $totalFailed++
            
            # Track failed count by kind if we have it
            if ($kind -and $kindCounts.ContainsKey($kind)) {
                $kindCounts[$kind].Failed++
            }
        }
    }
}

Write-Host "`n🎉 YAML conversion complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan

Write-Host "📊 Final Summary:" -ForegroundColor Cyan
Write-Host "   ✅ Total Converted: $totalConverted" -ForegroundColor Green
Write-Host "   ❌ Total Failed: $totalFailed" -ForegroundColor Red
if ($kindCounts) {
    Write-Host "   📁 Per Rule Kind Breakdown:" -ForegroundColor Cyan
    foreach ($kind in $kindCounts.Keys | Sort-Object) {
        $c = $kindCounts[$kind]
        Write-Host "      → $kind\: ✅ $($c.Converted) converted, ❌ $($c.Failed) failed" -ForegroundColor Gray
    }
}
Write-Host "`n📁 Output Location: $yamlOutputBasePath" -ForegroundColor Yellow
Write-Host "   Each rule type has been organized into its respective folder with human-readable filenames!" -ForegroundColor Gray
Write-Host "   These YAML templates are ready for Terraform ingestion and deployment." -ForegroundColor Gray