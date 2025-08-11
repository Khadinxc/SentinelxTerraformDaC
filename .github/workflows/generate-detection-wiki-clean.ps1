# Detection Wiki Generator - Markdown Edition (Clean Version)
# Generates Confluence-compatible Markdown wiki with structured content and GitHub integration

param(
    [Parameter(Mandatory=$false)]
    [string]$ManifestPath = ".sentinel\manifest.yaml",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\DetectionWiki\DetectionWiki.md",
    
    [Parameter(Mandatory=$false)]
    [string]$RepositoryUrl = "https://github.com/Khadinxc/SentinelxTerraform-DaC",
    
    [Parameter(Mandatory=$false)]
    [string]$Branch = "main",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "development",
    
    [Parameter(Mandatory=$false)]
    [string]$PageTitle = "Detection Rules Wiki"
)

# Import required modules
Import-Module powershell-yaml

# Ensure output directory exists
$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

Write-Host "MARKDOWN Detection Wiki Generator - Clean Version" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Manifest: $ManifestPath" -ForegroundColor Gray
Write-Host "Output: $OutputPath" -ForegroundColor Gray
Write-Host "Repository: $RepositoryUrl" -ForegroundColor Gray
Write-Host "Branch: $Branch" -ForegroundColor Gray
Write-Host "Environment: $Environment" -ForegroundColor Gray
Write-Host ""

# Load and validate manifest
Write-Host "Loading manifest..." -ForegroundColor Yellow
try {
    $yamlContent = Get-Content -Path $ManifestPath -Raw
    $manifest = ConvertFrom-Yaml $yamlContent
    
    # Collect all rule types
    $allRules = @()
    if ($manifest.content.scheduledRules) { $allRules += $manifest.content.scheduledRules }
    if ($manifest.content.nrtRules) { $allRules += $manifest.content.nrtRules }
    if ($manifest.content.fusionRules) { $allRules += $manifest.content.fusionRules }
    if ($manifest.content.microsoftRules) { $allRules += $manifest.content.microsoftRules }
    if ($manifest.content.threatIntelRules) { $allRules += $manifest.content.threatIntelRules }
    
    if ($allRules.Count -eq 0) {
        throw "No detection rules found in manifest"
    }
    
    $totalRules = $allRules.Count
    Write-Host "Loaded $totalRules detection rules" -ForegroundColor Green
} catch {
    Write-Error "Failed to load manifest: $($_.Exception.Message)"
    exit 1
}

# Helper functions
function Get-SeverityBadge {
    param([string]$Severity)
    
    switch ($Severity.ToLower()) {
        "high" { return "[HIGH]" }
        "medium" { return "[MED]" }
        "low" { return "[LOW]" }
        "informational" { return "[INFO]" }
        default { return "[UNK]" }
    }
}

function Get-StatusBadge {
    param([bool]$Enabled)
    
    if ($Enabled) {
        return "ENABLED"
    } else {
        return "DISABLED"
    }
}

function Get-RuleKindBadge {
    param([string]$Kind)
    
    switch ($Kind) {
        "Scheduled" { return "📊 Scheduled" }
        "NRT" { return "⚡ NRT" }
        "MicrosoftSecurityIncidentCreation" { return "🛡️ Microsoft" }
        "Fusion" { return "🤖 Fusion" }
        "ThreatIntelligence" { return "🎯 ThreatIntel" }
        default { return "❓ $Kind" }
    }
}

function Get-IntelligentTactics {
    param([object]$Rule)
    
    # Microsoft security rules don't have predefined tactics - they depend on the underlying product alerts
    if ($Rule.kind -eq "MicrosoftSecurityIncidentCreation") {
        return "_Determined by underlying alerts_"
    }
    
    # Fusion rules use ML and don't have predefined tactics
    if ($Rule.kind -eq "Fusion") {
        return "_ML-based correlation_"
    }
    
    # For other rule types, show actual tactics or "None specified"
    if ($Rule.tactics -and $Rule.tactics.Count -gt 0) {
        $validTactics = $Rule.tactics | Where-Object { $_ -and $_ -ne "UNK" }
        if ($validTactics.Count -gt 0) {
            return ($validTactics -join ", ")
        }
    }
    
    return "_None specified_"
}

function Get-IntelligentTechniques {
    param([object]$Rule)
    
    # Microsoft security rules don't have predefined techniques
    if ($Rule.kind -eq "MicrosoftSecurityIncidentCreation") {
        return "_Determined by underlying alerts_"
    }
    
    # Fusion rules use ML and don't have predefined techniques
    if ($Rule.kind -eq "Fusion") {
        return "_ML-based correlation_"
    }
    
    # For other rule types, show actual techniques or "None specified"
    if ($Rule.techniques -and $Rule.techniques.Count -gt 0) {
        $validTechniques = $Rule.techniques | Where-Object { $_ -and $_ -ne "UNK" }
        if ($validTechniques.Count -gt 0) {
            if ($validTechniques.Count -gt 3) {
                return ($validTechniques | Select-Object -First 3) -join ", " + "..."
            } else {
                return $validTechniques -join ", "
            }
        }
    }
    
    return "_None specified_"
}

function Get-IntelligentSeverity {
    param([object]$Rule)
    
    # Microsoft security rules inherit severity from the source product
    if ($Rule.kind -eq "MicrosoftSecurityIncidentCreation") {
        return "_Inherited from source_"
    }
    
    # Fusion rules typically use dynamic severity
    if ($Rule.kind -eq "Fusion") {
        return "_Dynamic (ML-based)_"
    }
    
    # For other rule types, show actual severity or "Not specified"
    if ($Rule.severity -and $Rule.severity -ne "UNK") {
        return $Rule.severity
    }
    
    return "_Not specified_"
}

function Get-RuleAnchor {
    param([string]$RuleName, [string]$PageTitle = "Detection Rules Wiki")
    
    # Create Confluence-style anchor: #PageTitle-RuleName
    # Remove special characters and convert to PascalCase for Confluence
    $cleanRuleName = $RuleName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', ''
    # For page title, Confluence uses the format we observed: DetectionRulesWiki
    $cleanPageTitle = "DetectionRulesWiki"  # Keep original format since that's what Confluence uses
    
    return "#$cleanPageTitle-$cleanRuleName"
}

function Get-GitHubUrl {
    param([string]$RepositoryUrl, [string]$Branch, [string]$RuleName)
    
    # URL encode the path to handle spaces and special characters
    $encodedRuleName = [uri]::EscapeDataString($RuleName)
    $encodedPath = [uri]::EscapeDataString("DetectionsYAML/Analytics Rules/")
    return "$RepositoryUrl/blob/$Branch/$encodedPath$encodedRuleName.yaml"
}

function Format-MitreTechniques {
    param([array]$Techniques, [object]$Rule = $null)
    
    # Handle rule-specific logic if Rule object is provided
    if ($Rule) {
        # Microsoft security rules don't have predefined techniques
        if ($Rule.kind -eq "MicrosoftSecurityIncidentCreation") {
            return "_Determined by underlying Microsoft security product alerts_"
        }
        
        # Fusion rules use ML and don't have predefined techniques
        if ($Rule.kind -eq "Fusion") {
            return "_ML-based correlation identifies techniques dynamically_"
        }
    }
    
    if (-not $Techniques -or $Techniques.Count -eq 0) {
        return "_None specified_"
    }
    
    $validTechniques = $Techniques | Where-Object { $_ -and $_ -ne "" -and $_ -ne "UNK" }
    if ($validTechniques.Count -eq 0) {
        return "_None specified_"
    }
    
    $formattedTechniques = $validTechniques | ForEach-Object {
        "[$_](https://attack.mitre.org/techniques/$($_.Replace('.', '/'))/)"
    }
    
    return ($formattedTechniques -join ", ")
}

# Generate statistics
Write-Host "Generating statistics..." -ForegroundColor Yellow

$rules = $allRules
$stats = @{
    Total = $rules.Count
    Enabled = ($rules | Where-Object { $_.enabled -eq $true }).Count
    Disabled = ($rules | Where-Object { $_.enabled -eq $false }).Count
    High = ($rules | Where-Object { $_.severity -eq "High" }).Count
    Medium = ($rules | Where-Object { $_.severity -eq "Medium" }).Count
    Low = ($rules | Where-Object { $_.severity -eq "Low" }).Count
    Info = ($rules | Where-Object { $_.severity -eq "Informational" }).Count
}

# Get unique tactics and techniques
$allTactics = $rules | ForEach-Object { 
    if ($_.tactics) { $_.tactics } 
} | Sort-Object -Unique
$allTechniques = $rules | ForEach-Object { 
    if ($_.techniques) { $_.techniques | Where-Object { $_ -and $_ -ne "" } } 
} | Where-Object { $_ } | Sort-Object -Unique

Write-Host "Statistics calculated" -ForegroundColor Green
Write-Host "   Total Rules: $($stats.Total)" -ForegroundColor Gray
Write-Host "   Enabled: $($stats.Enabled)" -ForegroundColor Gray
Write-Host "   MITRE Tactics: $($allTactics.Count)" -ForegroundColor Gray
Write-Host "   MITRE Techniques: $($allTechniques.Count)" -ForegroundColor Gray

# Start building Markdown content
Write-Host "Building Markdown wiki..." -ForegroundColor Yellow

# Initialize markdown content (page title is set by Confluence page title parameter)
$markdown = @()

# Create horizontal layout using a single table with three columns
$markdown += "| Wiki Information | Overview Statistics | Severity Distribution |"
$markdown += "|------------------|---------------------|----------------------|"
$markdown += "| **Status:** Auto-generated from manifest<br/>**Environment:** $Environment<br/>**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')<br/>**Repository:** [$($manifest.repository)]($RepositoryUrl)<br/>**Branch:** $Branch<br/>**Total Rules:** $($stats.Total) | **Total Rules:** $($stats.Total) (100%)<br/>**Enabled:** $($stats.Enabled) ($([Math]::Round($stats.Enabled / $stats.Total * 100, 1))%)<br/>**Disabled:** $($stats.Disabled) ($([Math]::Round($stats.Disabled / $stats.Total * 100, 1))%) | **High:** $($stats.High) (HIGH)<br/>**Medium:** $($stats.Medium) (MED)<br/>**Low:** $($stats.Low) (LOW)<br/>**Informational:** $($stats.Info) (INFO) |"
$markdown += ""

# MITRE ATT&CK Coverage
$markdown += "## MITRE ATT&CK Coverage"
$markdown += ""

# Only include enabled rules for coverage analysis
$enabledRules = $rules | Where-Object { $_.enabled -eq $true }
$enabledTactics = $enabledRules | ForEach-Object { 
    if ($_.tactics) { $_.tactics } 
} | Sort-Object -Unique

# Define all 14 MITRE ATT&CK tactics in proper order
$allMitreTactics = @(
    "Reconnaissance",
    "ResourceDevelopment", 
    "InitialAccess",
    "Execution", 
    "Persistence",
    "PrivilegeEscalation",
    "DefenseEvasion",
    "CredentialAccess",
    "Discovery",
    "LateralMovement",
    "Collection",
    "CommandAndControl",
    "Exfiltration",
    "Impact"
)

# Add summary statistics first
$markdown += "**Coverage Summary:**"
$markdown += "- **Tactics Covered:** $($enabledTactics.Count) of $($allMitreTactics.Count) MITRE ATT&CK tactics"
$markdown += "- **Enabled Rules:** $($enabledRules.Count)"
$markdown += "- **Techniques Covered:** $($allTechniques.Count)"
if ($enabledRules.Count -gt 0) {
    $markdown += "- **Coverage Density:** $([Math]::Round($allTechniques.Count / $enabledRules.Count, 2)) techniques per enabled rule"
} else {
    $markdown += "- **Coverage Density:** 0 techniques per enabled rule"
}
$markdown += ""

# Create simplified single-row MITRE coverage table
$tableHeader = "| Metric |"
foreach ($tactic in $allMitreTactics) {
    $tableHeader += " **$tactic** |"
}
$markdown += $tableHeader

# Create separator row
$tableSeparator = "|--------|"
foreach ($tactic in $allMitreTactics) {
    $tableSeparator += "----------|"
}
$markdown += $tableSeparator

# Rules row
$ruleCountRow = "| **Rules** |"
foreach ($tactic in $allMitreTactics) {
    $tacticRules = $enabledRules | Where-Object { 
        $_.tactics -and ($_.tactics -contains $tactic)
    }
    $actualCount = ($tacticRules | Measure-Object).Count
    $ruleCountRow += " $actualCount |"
}
$markdown += $ruleCountRow

# Top Techniques row
$techniqueRow = "| **Top Techniques** |"
foreach ($tactic in $allMitreTactics) {
    $tacticRules = $enabledRules | Where-Object { 
        $_.tactics -and ($_.tactics -contains $tactic)
    }
    $tacticTechniques = $tacticRules | ForEach-Object { 
        if ($_.techniques) { $_.techniques | Where-Object { $_ -and $_ -ne "" -and $_ -ne "UNK" } } 
    } | Where-Object { $_ } | Sort-Object -Unique | Select-Object -First 1
    
    if ($tacticTechniques.Count -gt 0) {
        $techniquesText = $tacticTechniques -join ", "
        # Check if there are more techniques
        $allTacticTechniques = $tacticRules | ForEach-Object { 
            if ($_.techniques) { $_.techniques | Where-Object { $_ -and $_ -ne "" -and $_ -ne "UNK" } } 
        } | Where-Object { $_ } | Sort-Object -Unique
        $allTacticTechniquesCount = ($allTacticTechniques | Measure-Object).Count
        if ($allTacticTechniquesCount -gt 1) {
            $techniquesText += " +$($allTacticTechniquesCount - 1) more"
        }
    } else {
        $techniquesText = "Nil"
    }
    $techniqueRow += " $techniquesText |"
}
$markdown += $techniqueRow

$markdown += ""

$markdown += "---"
$markdown += ""

# All Detection Rules Table
$markdown += "## All Detection Rules"
$markdown += ""
$markdown += "| Rule Name | Kind | Severity | Status | Tactics | Techniques | Links |"
$markdown += "|-----------|------|----------|--------|---------|------------|-------|"

# Add all rules to the table
foreach ($rule in $rules | Sort-Object name) {
    $kindBadge = Get-RuleKindBadge -Kind $rule.kind
    $intelligentSeverity = Get-IntelligentSeverity -Rule $rule
    $severityBadge = if ($intelligentSeverity.StartsWith("_")) { 
        $intelligentSeverity 
    } else { 
        Get-SeverityBadge -Severity $intelligentSeverity 
    }
    $statusBadge = Get-StatusBadge -Enabled $rule.enabled
    $ruleTactics = Get-IntelligentTactics -Rule $rule
    $ruleTechniques = Get-IntelligentTechniques -Rule $rule
    $githubUrl = Get-GitHubUrl -RepositoryUrl $RepositoryUrl -Branch $Branch -RuleName $rule.displayName
    $ruleAnchor = Get-RuleAnchor -RuleName $rule.displayName -PageTitle $PageTitle
    
    $markdown += "| **[$($rule.displayName)]($ruleAnchor)** | $kindBadge | $severityBadge | $statusBadge | $ruleTactics | $ruleTechniques | [GitHub]($githubUrl) |"
}

$markdown += ""
$markdown += "---"
$markdown += ""

# Detailed Rule Information
$markdown += "## Detailed Rule Information"
$markdown += ""

# Add detailed section for each rule
foreach ($rule in $rules | Sort-Object name) {
    $statusBadge = Get-StatusBadge -Enabled $rule.enabled
    $intelligentSeverity = Get-IntelligentSeverity -Rule $rule
    $githubUrl = Get-GitHubUrl -RepositoryUrl $RepositoryUrl -Branch $Branch -RuleName $rule.displayName
    $description = if ($rule.description) { $rule.description.Trim() } else { "_No description provided_" }
    $ruleAnchor = Get-RuleAnchor -RuleName $rule.displayName -PageTitle $PageTitle
    
    # Create Confluence-compatible heading ID (without the # prefix for the id attribute)
    $confluenceId = ($ruleAnchor -replace '^#', '')
    $markdown += "<h3 id=`"$confluenceId`">$($rule.displayName)</h3>"
    $markdown += ""
    
    # Rule summary table
    $markdown += "| Field | Value |"
    $markdown += "|-------|-------|"
    $markdown += "| **Status** | $statusBadge |"
    $markdown += "| **Severity** | $intelligentSeverity |"
    $markdown += "| **Source** | **[View Source]($githubUrl)** |"
    $markdown += ""
    
    $markdown += "<h4 id=`"$confluenceId-Description`">Description</h4>"
    $markdown += "$description"
    $markdown += ""
    
    $markdown += "<h4 id=`"$confluenceId-RuleDetails`">Rule Details</h4>"
    $markdown += ""
    $markdown += "| Property | Value |"
    $markdown += "|----------|-------|"
    
    # Add rule-type-specific details
    switch ($rule.kind) {
        "Scheduled" {
            $markdown += "| **Rule Type** | Scheduled Analytics Rule |"
            if ($rule.queryPeriod) { $markdown += "| **Query Period** | $($rule.queryPeriod) |" }
            if ($rule.queryFrequency) { $markdown += "| **Query Frequency** | $($rule.queryFrequency) |" }
            if ($rule.triggerOperator) { $markdown += "| **Trigger Operator** | $($rule.triggerOperator) |" }
            if ($rule.triggerThreshold) { $markdown += "| **Trigger Threshold** | $($rule.triggerThreshold) |" }
        }
        "NRT" {
            $markdown += "| **Rule Type** | Near Real-Time (NRT) Analytics Rule |"
            $markdown += "| **Processing** | Near real-time analysis |"
        }
        "MicrosoftSecurityIncidentCreation" {
            $markdown += "| **Rule Type** | Microsoft Security Product Integration |"
            $markdown += "| **Data Source** | Microsoft Security Products |"
            $markdown += "| **Processing** | Automatic incident creation from product alerts |"
            if ($rule.productFilter) { $markdown += "| **Product Filter** | $($rule.productFilter) |" }
        }
        "Fusion" {
            $markdown += "| **Rule Type** | Fusion Analytics Rule (Machine Learning) |"
            $markdown += "| **Technology** | Advanced correlation and machine learning |"
            $markdown += "| **Processing** | Multi-signal attack detection |"
        }
        default {
            $markdown += "| **Rule Type** | $($rule.kind) |"
        }
    }
    
    $markdown += ""
    
    $markdown += "<h4 id=`"$confluenceId-MITREMapping`">MITRE ATT&CK Mapping</h4>"
    $markdown += ""
    $markdown += "| Category | Value |"
    $markdown += "|----------|-------|"
    $markdown += "| **Tactics** | $(Get-IntelligentTactics -Rule $rule) |"
    $markdown += "| **Techniques** | $(Format-MitreTechniques -Techniques $rule.techniques -Rule $rule) |"
    $markdown += ""
    
    $markdown += "<h4 id=`"$confluenceId-EntityMappings`">Entity Mappings</h4>"
    $markdown += ""
    
    # Handle entity mappings intelligently based on rule type
    if ($rule.kind -eq "MicrosoftSecurityIncidentCreation") {
        $markdown += "- _Entity mappings are inherited from the underlying Microsoft security product alerts_"
    } elseif ($rule.kind -eq "Fusion") {
        $markdown += "- _Entity mappings are dynamically determined by the ML correlation engine_"
    } elseif ($rule.entityMappings -and $rule.entityMappings.Count -gt 0) {
        $rule.entityMappings | ForEach-Object {
            $entityType = if ($_.entity_type) { $_.entity_type } else { $_.entityType }
            $fieldMappings = if ($_.field_mappings) { $_.field_mappings } else { $_.fieldMappings }
            if ($fieldMappings) {
                $mappingList = $fieldMappings | ForEach-Object { 
                    $identifier = if ($_.identifier) { $_.identifier } else { "N/A" }
                    $columnName = if ($_.column_name) { $_.column_name } else { $_.columnName }
                    "$identifier -> $columnName"
                }
                $markdown += "- **${entityType}:** $($mappingList -join ', ')"
            } else {
                $markdown += "- **${entityType}:** No field mappings"
            }
        }
    } else {
        $markdown += "- _No entity mappings configured_"
    }
    $markdown += ""
    $markdown += "---"
    $markdown += ""
}

# Add footer
$markdown += "## Additional Resources"
$markdown += ""
$markdown += "### Repository Information"
$markdown += "- **Repository:** [$($manifest.repository)]($RepositoryUrl)"
$markdown += "- **Branch:** $Branch"
$markdown += "- **Last Updated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
$markdown += "- **Environment:** $Environment"
$markdown += ""
$markdown += "### MITRE ATT&CK Framework"
$markdown += "- **Official Website:** [attack.mitre.org](https://attack.mitre.org/)"
$markdown += "- **Tactics Documentation:** [MITRE ATT&CK Tactics](https://attack.mitre.org/tactics/enterprise/)"
$markdown += "- **Techniques Documentation:** [MITRE ATT&CK Techniques](https://attack.mitre.org/techniques/enterprise/)"
$markdown += ""
$markdown += "### Microsoft Sentinel"
$markdown += "- **Analytics Rules:** [Microsoft Documentation](https://docs.microsoft.com/en-us/azure/sentinel/detect-threats-built-in)"
$markdown += "- **KQL Reference:** [Kusto Query Language](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)"
$markdown += "- **Community Rules:** [Azure Sentinel GitHub](https://github.com/Azure/Azure-Sentinel)"
$markdown += ""
$markdown += "---"
$markdown += ""
$markdown += "**This wiki was automatically generated from the detection manifest at** `$ManifestPath` "
$markdown += "**Generation time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')**"

# Write the Markdown file
$outputFile = $OutputPath
Write-Host "Writing Markdown file..." -ForegroundColor Yellow

# Convert markdown array to string with proper line breaks
$markdownContent = $markdown -join "`n"

try {
    $markdownContent | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "Markdown wiki generated successfully" -ForegroundColor Green
    Write-Host "   File: $outputFile" -ForegroundColor Gray
    Write-Host "   Size: $([Math]::Round((Get-Item $outputFile).Length / 1KB, 2)) KB" -ForegroundColor Gray
} catch {
    Write-Error "Failed to write Markdown file: $($_.Exception.Message)"
    exit 1
}

# Generate metadata file
Write-Host "Generating metadata..." -ForegroundColor Yellow

$metadata = @{
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
    environment = $Environment
    repository = $manifest.repository
    branch = $Branch
    manifestPath = $ManifestPath
    totalRules = $stats.Total
    enabledRules = $stats.Enabled
    disabledRules = $stats.Disabled
    severityDistribution = @{
        high = $stats.High
        medium = $stats.Medium
        low = $stats.Low
        informational = $stats.Info
    }
    mitreCoverage = @{
        tactics = $allTactics.Count
        techniques = $allTechniques.Count
        tacticsList = $allTactics
        techniquesList = $allTechniques
    }
    outputFiles = @{
        markdown = "DetectionWiki.md"
        metadata = "wiki-metadata.json"
    }
} | ConvertTo-Json -Depth 10

$metadataFile = Join-Path (Split-Path -Parent $OutputPath) "wiki-metadata.json"
try {
    $metadata | Out-File -FilePath $metadataFile -Encoding UTF8
    Write-Host "Metadata file generated" -ForegroundColor Green
    Write-Host "   File: $metadataFile" -ForegroundColor Gray
} catch {
    Write-Error "Failed to write metadata file: $($_.Exception.Message)"
    exit 1
}

# Final summary
Write-Host ""
Write-Host "Wiki generation completed!" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green
Write-Host "Markdown File: $outputFile" -ForegroundColor White
Write-Host "Metadata File: $metadataFile" -ForegroundColor White
Write-Host "Total Rules: $($stats.Total)" -ForegroundColor White
Write-Host "Enabled: $($stats.Enabled)" -ForegroundColor Green
Write-Host "Disabled: $($stats.Disabled)" -ForegroundColor Red
Write-Host "MITRE Tactics: $($allTactics.Count)" -ForegroundColor Yellow
Write-Host "MITRE Techniques: $($allTechniques.Count)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Review the generated Markdown file" -ForegroundColor White
Write-Host "2. Push to Confluence using the push pipeline" -ForegroundColor White
Write-Host "3. Verify formatting and links in Confluence" -ForegroundColor White
