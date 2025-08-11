# PowerShell script for validating detection rules
# This script validates the YAML content files and KQL queries

param(
    [Parameter(Mandatory=$false)]
    [string]$ContentPath = ".\content",
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateKQL = $false
)

Write-Host "SentinelDaC Content Validation Script" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Function to validate YAML files
function Test-YamlFile {
    param([string]$FilePath)
    
    try {
        $content = Get-Content $FilePath -Raw
        # Basic YAML validation - check for proper structure
        if ($content -match "^[^:]+:$" -and $content -match "^\s+[^:]+:") {
            Write-Host "✓ Valid YAML structure: $FilePath" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "⚠ Potential YAML structure issues: $FilePath"
            return $false
        }
    } catch {
        Write-Error "✗ Failed to read YAML file: $FilePath - $($_.Exception.Message)"
        return $false
    }
}

# Function to validate KQL queries
function Test-KQLQuery {
    param([string]$Query, [string]$RuleName)
    
    # Basic KQL validation checks
    $issues = @()
    
    # Check for common KQL patterns
    if ($Query -notmatch "^\s*(union|search|\w+)\s*") {
        $issues += "Query should start with a table name, union, or search operator"
    }
    
    # Check for proper pipe usage
    if ($Query -match "\|\s*$") {
        $issues += "Query ends with a pipe operator"
    }
    
    # Check for common mistakes
    if ($Query -match "where.*=.*'.*'.*and.*=.*'.*'" -and $Query -notmatch "where.*==") {
        $issues += "Consider using == instead of = for comparisons"
    }
    
    if ($issues.Count -eq 0) {
        Write-Host "✓ KQL Query validation passed: $RuleName" -ForegroundColor Green
        return $true
    } else {
        Write-Warning "⚠ KQL Query issues found in $RuleName"
        foreach ($issue in $issues) {
            Write-Host "  - $issue" -ForegroundColor Yellow
        }
        return $false
    }
}

# Main validation logic
$validationResults = @{
    TotalFiles = 0
    ValidFiles = 0
    FailedFiles = 0
    TotalQueries = 0
    ValidQueries = 0
    FailedQueries = 0
}

Write-Host "`nValidating content files..." -ForegroundColor Blue

# Find all YAML files
$yamlFiles = Get-ChildItem -Path $ContentPath -Filter "*.yaml" -Recurse
$validationResults.TotalFiles = $yamlFiles.Count

foreach ($file in $yamlFiles) {
    Write-Host "`nValidating: $($file.FullName)" -ForegroundColor Cyan
    
    if (Test-YamlFile -FilePath $file.FullName) {
        $validationResults.ValidFiles++
        
        # If KQL validation is requested and this is a scheduled rules file
        if ($ValidateKQL -and $file.Name -eq "rules.yaml" -and $file.Directory.Name -eq "scheduled-rules") {
            try {
                $content = Get-Content $file.FullName -Raw | ConvertFrom-Yaml
                foreach ($ruleKey in $content.Keys) {
                    $rule = $content[$ruleKey]
                    if ($rule.query) {
                        $validationResults.TotalQueries++
                        if (Test-KQLQuery -Query $rule.query -RuleName $ruleKey) {
                            $validationResults.ValidQueries++
                        } else {
                            $validationResults.FailedQueries++
                        }
                    }
                }
            } catch {
                Write-Warning "Could not parse YAML content for KQL validation: $($_.Exception.Message)"
            }
        }
    } else {
        $validationResults.FailedFiles++
    }
}

# Display results
Write-Host "`n" + "="*50 -ForegroundColor Green
Write-Host "VALIDATION RESULTS" -ForegroundColor Green
Write-Host "="*50 -ForegroundColor Green

Write-Host "Files:" -ForegroundColor White
Write-Host "  Total: $($validationResults.TotalFiles)" -ForegroundColor White
Write-Host "  Valid: $($validationResults.ValidFiles)" -ForegroundColor Green
Write-Host "  Failed: $($validationResults.FailedFiles)" -ForegroundColor Red

if ($ValidateKQL) {
    Write-Host "`nKQL Queries:" -ForegroundColor White
    Write-Host "  Total: $($validationResults.TotalQueries)" -ForegroundColor White
    Write-Host "  Valid: $($validationResults.ValidQueries)" -ForegroundColor Green
    Write-Host "  Issues: $($validationResults.FailedQueries)" -ForegroundColor Yellow
}

if ($validationResults.FailedFiles -eq 0 -and $validationResults.FailedQueries -eq 0) {
    Write-Host "`n✓ All validations passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠ Some validations failed. Please review the issues above." -ForegroundColor Yellow
    exit 1
}
