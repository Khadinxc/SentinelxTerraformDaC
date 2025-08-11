# json-to-yaml.ps1
# Converts JSON alert rules → YAML with human-readable filenames (manifest generation removed)

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
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

# Input/Output paths
$inputDir  = "Detections/Analytics Rules"     # Updated to match your export structure
$outputDir = "DetectionsYAML/Analytics Rules" # Updated to match your export structure

# Ensure output folder exists
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Write-Host "🔄 Converting JSON templates to YAML..." -ForegroundColor Cyan
Write-Host "   Input:  $inputDir" -ForegroundColor Gray
Write-Host "   Output: $outputDir" -ForegroundColor Gray

$convertedCount = 0
$failedCount = 0

# Convert each file
Get-ChildItem -Path $inputDir -Filter *.json | ForEach-Object {
    $jsonPath = $_.FullName
    $baseName = $_.BaseName

    try {
        # Read and convert JSON to PowerShell object first
        $jsonContent = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json
        
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
            Write-Host "📝 Using display name: '$displayName' → '$fileName'"
        } else {
            $fileName = $baseName
            Write-Host "⚠️  No display name found, using original: '$fileName'"
        }
        
        $yamlPath = Join-Path $outputDir "$fileName.yaml"
        
        # Convert to YAML and save
        $yaml = ConvertTo-Yaml $jsonContent
        Set-Content -Path $yamlPath -Value $yaml -Encoding utf8
        
        Write-Host "✅ Converted $baseName → $fileName.yaml" -ForegroundColor Green
        $convertedCount++
    }
    catch {
        Write-Warning "❌ Failed to convert $($_.Name): $_"
        
        # Fallback: create with original name if conversion fails
        try {
            $yamlPath = Join-Path $outputDir "$baseName.yaml"
            $yaml = ConvertTo-Yaml $jsonContent
            Set-Content -Path $yamlPath -Value $yaml -Encoding utf8
            Write-Host "🔄 Fallback conversion: $baseName.yaml" -ForegroundColor Yellow
            $convertedCount++
        }
        catch {
            Write-Error "💥 Complete failure for $jsonPath`: $_"
            $failedCount++
        }
    }
}

Write-Host "`n📊 Conversion Summary:" -ForegroundColor Cyan
Write-Host "   ✅ Converted: $convertedCount files" -ForegroundColor Green
if ($failedCount -gt 0) {
    Write-Host "   ❌ Failed: $failedCount files" -ForegroundColor Red
}

Write-Host "`n🎉 JSON to YAML conversion complete with human-readable filenames!" -ForegroundColor Green
