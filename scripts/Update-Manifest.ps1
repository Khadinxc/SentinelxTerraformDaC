#Requires -Version 5.1
<#
.SYNOPSIS
    Sentinel Manifest Updater
    
.DESCRIPTION
    This script automatically updates the manifest.yaml file by scanning the content directories
    and reflecting the actual rules present in each directory.
    
.PARAMETER ProjectRoot
    The root directory of the SentinelxTerraform-DaC project. Defaults to parent of script directory.
    
.PARAMETER ContentDir
    The content directory path. Defaults to 'content' under ProjectRoot.
    
.PARAMETER ManifestFile
    The manifest file path. Defaults to '.sentinel\manifest.yaml' under ProjectRoot.
    
.PARAMETER DryRun
    Show what would be done without actually updating the manifest file.
    
.EXAMPLE
    .\Update-Manifest.ps1
    
.EXAMPLE
    .\Update-Manifest.ps1 -DryRun
    
.EXAMPLE
    .\Update-Manifest.ps1 -ProjectRoot "D:\MyProject"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    
    [Parameter()]
    [string]$ContentDir = "content",
    
    [Parameter()]
    [string]$ManifestFile = ".sentinel\manifest.yaml",
    
    [Parameter()]
    [switch]$DryRun
)

# Import required modules
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Warning "powershell-yaml module not found. Installing..."
    try {
        Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AllowClobber
        Import-Module powershell-yaml
    }
    catch {
        Write-Error "Failed to install powershell-yaml module. Please install manually: Install-Module powershell-yaml"
        exit 1
    }
}
else {
    Import-Module powershell-yaml -ErrorAction Stop
}

# Global variables
$ContentPath = Join-Path $ProjectRoot $ContentDir
$ManifestPath = Join-Path $ProjectRoot $ManifestFile

# Directory to manifest section mapping - Only rule directories
$DirectoryMapping = @{
    "fusion-rules" = "fusionRules"
    "microsoft-rules" = "microsoftRules"
    "scheduled-rules" = "scheduledRules"
    "nrt-rules" = "nrtRules"  # NRT rules are also analytics rules
    "threat-intel-rules" = "threatIntelligenceRules"
}

# Rule kind mapping based on directory
$KindMapping = @{
    "fusion-rules" = "Fusion"
    "microsoft-rules" = "MicrosoftSecurityIncidentCreation"
    "scheduled-rules" = "Scheduled"
    "nrt-rules" = "NRT"
    "threat-intel-rules" = "ThreatIntelligence"
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'Info' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-ManifestContent {
    <#
    .SYNOPSIS
        Load existing manifest file or create basic structure.
    #>
    param(
        [string]$Path
    )
    
    if (Test-Path $Path) {
        try {
            $content = Get-Content $Path -Raw -Encoding UTF8
            return ConvertFrom-Yaml $content
        }
        catch {
            Write-Log "Error loading manifest: $($_.Exception.Message)" -Level Error
            throw
        }
    }
    else {
        Write-Log "Manifest file not found at $Path, creating basic structure..." -Level Warning
        return @{
            schemaVersion = "1.0"
            workspace = "law-sentinel-dev"
            repository = "github.com/Khadinxc/Sentinel-CICD-Detections"
            branch = "main"
            content = @{}
        }
    }
}

function Get-YamlFileContent {
    <#
    .SYNOPSIS
        Parse a YAML rule file and extract metadata.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    try {
        # Check if file is empty
        $fileInfo = Get-Item $FilePath
        if ($fileInfo.Length -eq 0) {
            Write-Verbose "Skipping empty file: $FilePath"
            return $null
        }
        
        $content = Get-Content $FilePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Verbose "Skipping file with no content: $FilePath"
            return $null
        }
        
        return ConvertFrom-Yaml $content
    }
    catch {
        Write-Log "Error parsing $FilePath`: $($_.Exception.Message)" -Level Warning
        return $null
    }
}

function Get-RuleMetadata {
    <#
    .SYNOPSIS
        Extract rule metadata for manifest entry.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$RuleData,
        
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [Parameter(Mandatory)]
        [string]$Directory
    )
    
    # Generate or extract rule ID
    $ruleId = if ($RuleData.ContainsKey('alert_rule_template_guid')) {
        $RuleData.alert_rule_template_guid
    } else {
        [System.Guid]::NewGuid().ToString()
    }
    
    # Extract display name
    $displayName = if ($RuleData.ContainsKey('display_name')) {
        $RuleData.display_name
    } else {
        (Get-Item $FilePath).BaseName -replace '_', ' ' -replace '-', ' ' | 
            ForEach-Object { (Get-Culture).TextInfo.ToTitleCase($_) }
    }
    
    # Extract description
    $description = if ($RuleData.ContainsKey('description')) {
        $RuleData.description
    } else {
        "Rule from $(Split-Path $FilePath -Leaf)"
    }
    
    # Extract enabled status
    $enabled = if ($RuleData.ContainsKey('enabled')) {
        $RuleData.enabled
    } else {
        $true
    }
    
    # Extract severity
    $severity = if ($RuleData.ContainsKey('severity') -and $RuleData.severity -and $RuleData.severity.ToString().Trim() -ne "") {
        $RuleData.severity.ToString().Trim()
    } else {
        "UNK"
    }
    
    # Extract tactics (ensure array)
    $tactics = if ($RuleData.ContainsKey('tactics') -and $RuleData.tactics) {
        # PowerShell YAML module returns arrays as Object[]
        $tacticsList = @($RuleData.tactics)
        $filteredTactics = $tacticsList | Where-Object { $_ -ne $null -and $_.ToString().Trim() -ne "" } | ForEach-Object { $_.ToString().Trim() }
        if ($filteredTactics.Count -gt 0) {
            $filteredTactics
        } else {
            @("UNK")
        }
    } else {
        @("UNK")
    }
    
    # Extract techniques (ensure array)
    $techniques = if ($RuleData.ContainsKey('techniques') -and $RuleData.techniques) {
        # PowerShell YAML module returns arrays as Object[]
        $techniquesList = @($RuleData.techniques)
        $filteredTechniques = $techniquesList | Where-Object { $_ -ne $null -and $_.ToString().Trim() -ne "" } | ForEach-Object { $_.ToString().Trim() }
        if ($filteredTechniques.Count -gt 0) {
            $filteredTechniques
        } else {
            @("UNK")
        }
    } else {
        @("UNK")
    }
    
    # Determine rule kind
    $kind = if ($KindMapping.ContainsKey($Directory)) {
        $KindMapping[$Directory]
    } else {
        "Scheduled"
    }
    
    # Build base manifest entry
    $manifestEntry = @{
        name = $ruleId
        displayName = $displayName
        file = $FilePath -replace '\\', '/'
        enabled = $enabled
        severity = $severity
        tactics = $tactics
        techniques = $techniques
        description = $description
        kind = $kind
    }
    
    # Add rule-specific fields based on rule type
    switch ($kind) {
        "Scheduled" {
            # Add scheduled rule specific fields if they exist
            if ($RuleData.ContainsKey('query_frequency')) {
                $manifestEntry.queryFrequency = $RuleData.query_frequency
            }
            if ($RuleData.ContainsKey('query_period')) {
                $manifestEntry.queryPeriod = $RuleData.query_period
            }
            if ($RuleData.ContainsKey('trigger_operator')) {
                $manifestEntry.triggerOperator = $RuleData.trigger_operator
            }
            if ($RuleData.ContainsKey('trigger_threshold')) {
                $manifestEntry.triggerThreshold = $RuleData.trigger_threshold
            }
            if ($RuleData.ContainsKey('suppression_enabled')) {
                $manifestEntry.suppressionEnabled = $RuleData.suppression_enabled
            }
            if ($RuleData.ContainsKey('suppression_duration')) {
                $manifestEntry.suppressionDuration = $RuleData.suppression_duration
            }
            # Add entity mappings if they exist
            if ($RuleData.ContainsKey('entity_mappings') -and $RuleData.entity_mappings) {
                $manifestEntry.entityMappings = $RuleData.entity_mappings
            }
        }
        "NRT" {
            # NRT rules have similar fields but may have different defaults
            if ($RuleData.ContainsKey('query')) {
                $manifestEntry.hasQuery = $true
            }
            # Add entity mappings if they exist
            if ($RuleData.ContainsKey('entity_mappings') -and $RuleData.entity_mappings) {
                $manifestEntry.entityMappings = $RuleData.entity_mappings
            }
        }
        "MicrosoftSecurityIncidentCreation" {
            # Microsoft rules have product filter
            if ($RuleData.ContainsKey('product_filter')) {
                $manifestEntry.productFilter = $RuleData.product_filter
            }
            if ($RuleData.ContainsKey('alert_rule_template_guid')) {
                $manifestEntry.alertRuleTemplateGuid = $RuleData.alert_rule_template_guid
            }
            if ($RuleData.ContainsKey('alert_rule_template_version')) {
                $manifestEntry.alertRuleTemplateVersion = $RuleData.alert_rule_template_version
            }
            # Add entity mappings if they exist
            if ($RuleData.ContainsKey('entity_mappings') -and $RuleData.entity_mappings) {
                $manifestEntry.entityMappings = $RuleData.entity_mappings
            }
        }
        "Fusion" {
            # Fusion rules may have source settings
            if ($RuleData.ContainsKey('alert_rule_template_guid')) {
                $manifestEntry.alertRuleTemplateGuid = $RuleData.alert_rule_template_guid
            }
            if ($RuleData.ContainsKey('alert_rule_template_version')) {
                $manifestEntry.alertRuleTemplateVersion = $RuleData.alert_rule_template_version
            }
            # Add entity mappings if they exist
            if ($RuleData.ContainsKey('entity_mappings') -and $RuleData.entity_mappings) {
                $manifestEntry.entityMappings = $RuleData.entity_mappings
            }
        }
    }
    
    # Debug output
    Write-Verbose "Rule: $displayName"
    Write-Verbose "  Kind: $kind"
    Write-Verbose "  Severity: '$severity'"
    Write-Verbose "  Tactics: $($tactics -join ', ')"
    Write-Verbose "  Techniques: $($techniques -join ', ')"
    if ($manifestEntry.ContainsKey('queryFrequency')) {
        Write-Verbose "  Query Frequency: $($manifestEntry.queryFrequency)"
    }
    if ($manifestEntry.ContainsKey('queryPeriod')) {
        Write-Verbose "  Query Period: $($manifestEntry.queryPeriod)"
    }
    
    return $manifestEntry
}

function Get-ContentDirectoryRules {
    <#
    .SYNOPSIS
        Scan a content directory and return list of rule entries.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )
    
    $dirPath = Join-Path $ContentPath $Directory
    
    if (-not (Test-Path $dirPath)) {
        Write-Log "Directory $dirPath does not exist, skipping..." -Level Info
        return @()
    }
    
    $yamlFiles = @(Get-ChildItem -Path $dirPath -Filter "*.yaml" -File)
    $ymlFiles = @(Get-ChildItem -Path $dirPath -Filter "*.yml" -File)
    $allFiles = $yamlFiles + $ymlFiles
    
    Write-Log "Found $($allFiles.Count) YAML files in $Directory" -Level Info
    
    $rules = [System.Collections.ArrayList]@()
    foreach ($file in $allFiles) {
        $ruleData = Get-YamlFileContent -FilePath $file.FullName
        if ($ruleData) {
            $ruleEntry = Get-RuleMetadata -RuleData $ruleData -FilePath $file.FullName -Directory $Directory
            [void]$rules.Add($ruleEntry)
            Write-Verbose "Processed: $($file.Name)"
        }
    }
    
    Write-Log "Successfully processed $($rules.Count) rules from $Directory" -Level Info
    return $rules.ToArray()
}

function Update-ManifestFile {
    <#
    .SYNOPSIS
        Update the manifest file with current content.
    #>
    
    Write-Log "Starting manifest update..." -Level Info
    Write-Log "Project root: $ProjectRoot" -Level Info
    Write-Log "Content directory: $ContentPath" -Level Info
    Write-Log "Manifest file: $ManifestPath" -Level Info
    
    # Load existing manifest
    $manifest = Get-ManifestContent -Path $ManifestPath
    
    # Initialize/clear content section to start fresh
    $manifest.content = @{}
    
    # Process each content directory
    foreach ($directory in $DirectoryMapping.Keys) {
        $manifestSection = $DirectoryMapping[$directory]
        Write-Log "Processing $directory directory..." -Level Info
        
        $rules = Get-ContentDirectoryRules -Directory $directory
        
        if ($rules.Count -gt 0) {
            # Handle multiple directories mapping to same section (like analyticsRules)
            if ($manifest.content.ContainsKey($manifestSection)) {
                # Merge rules if section already exists
                $existingRules = $manifest.content[$manifestSection]
                $manifest.content[$manifestSection] = @($existingRules) + @($rules)
                Write-Log "Merged $($rules.Count) additional rules into existing $manifestSection section" -Level Success
            } else {
                $manifest.content[$manifestSection] = @($rules)
                Write-Log "Added $($rules.Count) rules to $manifestSection" -Level Success
            }
        } else {
            Write-Log "No rules found for $directory" -Level Info
        }
    }
    
    # Clean up empty sections
    $sectionsToRemove = @()
    foreach ($section in $manifest.content.Keys) {
        $sectionRules = $manifest.content[$section]
        if (-not $sectionRules -or ($sectionRules -is [array] -and $sectionRules.Count -eq 0)) {
            $sectionsToRemove += $section
        }
    }
    
    foreach ($section in $sectionsToRemove) {
        $manifest.content.Remove($section)
        Write-Log "Removed empty section: $section" -Level Info
    }
    
    # Calculate total rules
    $totalRules = 0
    foreach ($section in $manifest.content.Values) {
        if ($section -is [array]) {
            $totalRules += $section.Count
        } elseif ($section) {
            $totalRules += 1
        }
    }
    
    if ($DryRun) {
        Write-Log "DryRun: Would update manifest with $totalRules total rules" -Level Info
        return $manifest
    }
    
    # Save updated manifest
    Save-ManifestFile -Manifest $manifest -Path $ManifestPath
    Write-Log "Manifest updated successfully with $totalRules total rules" -Level Success
    
    return $manifest
}

function Save-ManifestFile {
    <#
    .SYNOPSIS
        Save the updated manifest to file.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest,
        
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    try {
        # Ensure directory exists
        $manifestDir = Split-Path $Path -Parent
        if (-not (Test-Path $manifestDir)) {
            New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        }
        
        # Convert to YAML and save
        $yamlContent = ConvertTo-Yaml $Manifest
        Set-Content -Path $Path -Value $yamlContent -Encoding UTF8
        
        Write-Log "Manifest saved to $Path" -Level Success
    }
    catch {
        Write-Log "Error saving manifest: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Show-ManifestSummary {
    <#
    .SYNOPSIS
        Print a summary of the manifest contents.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )
    
    $content = $Manifest.content
    
    Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
    Write-Host "MANIFEST SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host "Workspace: $($Manifest.workspace ?? 'N/A')" -ForegroundColor White
    Write-Host "Repository: $($Manifest.repository ?? 'N/A')" -ForegroundColor White
    Write-Host "Branch: $($Manifest.branch ?? 'N/A')" -ForegroundColor White
    Write-Host ""
    
    $totalRules = 0
    foreach ($section in $content.Keys | Sort-Object) {
        $rules = $content[$section]
        $count = if ($rules -is [array]) { $rules.Count } elseif ($rules) { 1 } else { 0 }
        $totalRules += $count
        Write-Host "$section`: $count rules" -ForegroundColor Green
    }
    
    Write-Host "`nTotal Rules: $totalRules" -ForegroundColor Yellow
    Write-Host ("=" * 50) -ForegroundColor Cyan
}

# Main execution
try {
    Write-Log "Sentinel Manifest Updater Starting..." -Level Info
    
    # Validate paths
    if (-not (Test-Path $ProjectRoot)) {
        throw "Project root directory not found: $ProjectRoot"
    }
    
    if (-not (Test-Path $ContentPath)) {
        throw "Content directory not found: $ContentPath"
    }
    
    # Update manifest
    $updatedManifest = Update-ManifestFile
    
    # Show summary
    Show-ManifestSummary -Manifest $updatedManifest
    
    Write-Log "Manifest update completed successfully!" -Level Success
}
catch {
    Write-Log "Error: $($_.Exception.Message)" -Level Error
    exit 1
}
