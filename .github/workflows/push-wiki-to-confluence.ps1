# Push Wiki to Confluence PowerShell Script
# Handles the actual upload of HTML wiki content to Confluence

param(
    [Parameter(Mandatory=$false)]
    [string]$WikiFilePath = "DetectionWiki/DetectionWiki.md",
    
    [Parameter(Mandatory=$false)]
    [string]$ConfluenceUrl = "your-confluence-url",
    
    [Parameter(Mandatory=$false)]
    [string]$SpaceKey = "your-space-key",
    
    [Parameter(Mandatory=$false)]
    [string]$ParentPageId = "your-parent-page-id",
    
    [Parameter(Mandatory=$false)]
    [string]$AccessToken = "your-access-token-here",
    
    [Parameter(Mandatory=$false)]
    [string]$PageTitle = "Detection Rules Wiki",
    
    [Parameter(Mandatory=$false)]
    [bool]$ForceUpdate = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "development"
)

# Set error handling
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        "Info" { "Cyan" }
        default { "White" }
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Test-ConfluenceConnectivity {
    param([hashtable]$Headers)
    
    Write-Log "Testing Confluence connectivity..." "Info"
    
    try {
        $spaceUrl = "$ConfluenceUrl/rest/api/space/$SpaceKey"
        $response = Invoke-RestMethod -Uri $spaceUrl -Headers $Headers -TimeoutSec 30
        
        Write-Log "✅ Confluence connectivity successful" "Success"
        Write-Log "   Space: $($response.name) ($($response.key))" "Info"
        
        return $response
    } catch {
        Write-Log "❌ Confluence connectivity failed: $($_.Exception.Message)" "Error"
        if ($_.Exception.Response) {
            Write-Log "   Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Response.StatusDescription)" "Error"
        }
        throw
    }
}

function Get-ExistingPage {
    param([hashtable]$Headers, [string]$Title, [string]$BaseUrl, [string]$Space)
    
    Write-Log "Checking for existing page: '$Title'" "Info"
    Write-Log "   BaseUrl: $BaseUrl" "Info"
    Write-Log "   Space: $Space" "Info"
    
    try {
        $searchUrl = "$BaseUrl/rest/api/content"
        Write-Log "   searchUrl: $searchUrl" "Info"
        $params = @{
            spaceKey = $Space
            title = $Title
            expand = "version,space,ancestors"
        }
        
        $query = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join "&"
        Write-Log "   query: $query" "Info"
        $fullUrl = $searchUrl + "?" + $query
        
        Write-Log "   Full Search URL: $fullUrl" "Info"
        $response = Invoke-RestMethod -Uri $fullUrl -Headers $Headers
        
        Write-Log "   Search returned $($response.results.Count) results" "Info"
        
        if ($response.results -and $response.results.Count -gt 0) {
            $page = $response.results[0]
            Write-Log "✅ Found existing page (ID: $($page.id), Version: $($page.version.number))" "Success"
            Write-Log "   Page title: '$($page.title)'" "Info"
            return $page
        } else {
            Write-Log "ℹ️ No existing page found with title '$Title'" "Info"
            return $null
        }
    } catch {
        Write-Log "⚠️ Error checking for existing page: $($_.Exception.Message)" "Warning"
        return $null
    }
}

function Read-WikiContent {
    param([string]$FilePath)
    
    Write-Log "Reading wiki content from: $FilePath" "Info"
    
    if (-not (Test-Path $FilePath)) {
        throw "Wiki file not found: $FilePath"
    }
    
    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    $fileSize = (Get-Item $FilePath).Length
    
    Write-Log "✅ Wiki content loaded" "Success"
    Write-Log "   File size: $([Math]::Round($fileSize/1KB, 2)) KB" "Info"
    Write-Log "   Content length: $($content.Length) characters" "Info"
    
    return $content
}

function Convert-MarkdownToConfluenceStorage {
    param([string]$MarkdownContent)
    
    Write-Log "Converting Markdown to Confluence storage format..." "Info"
    
    # Convert Markdown to proper HTML tables for Confluence
    $storageContent = $MarkdownContent
    
    # Convert headers to Confluence format (but skip already converted HTML headers)
    $storageContent = $storageContent -replace '^# (.+)$', '<h1>$1</h1>'
    $storageContent = $storageContent -replace '(?m)^## (.+)$', '<h2>$1</h2>'
    # Don't convert ### headers if they're already HTML (from wiki generator)
    $storageContent = $storageContent -replace '(?m)^### (?!.*<h3)(.+)$', '<h3>$1</h3>'
    
    # Convert bold text
    $storageContent = $storageContent -replace '\*\*([^*]+)\*\*', '<strong>$1</strong>'
    
    # Convert inline code (backticks) to HTML code tags
    $storageContent = $storageContent -replace '`([^`]+)`', '<code>$1</code>'
    
    # Convert internal anchor links (starting with #) for Confluence
    $storageContent = $storageContent -replace '\[([^\]]+)\]\(#([^)]+)\)', '<a href="#$2" rel="nofollow">$1</a>'
    
    # Convert external links with proper Confluence formatting
    $storageContent = $storageContent -replace '\[([^\]]+)\]\(([^#][^)]*)\)', '<a href="$2" class="external-link" rel="nofollow">$1</a>'
    
    # Handle horizontal rules - use proper Confluence format
    $storageContent = $storageContent -replace '^---$', '<hr/>'
    $storageContent = $storageContent -replace '(?m)^---$', '<hr/>'
    
    # Convert tables to proper Confluence HTML tables
    $lines = $storageContent -split "`n"
    $processedLines = @()
    $inTable = $false
    $isFirstTableRow = $true
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        if ($line -match '^\|.*\|$' -and $line -notmatch '^\|[-\s\|:]+\|$') {
            if (-not $inTable) {
                $processedLines += '<div class="table-wrap"><table class="confluenceTable">'
                $processedLines += '<tbody>'
                $inTable = $true
                $isFirstTableRow = $true
            }
            
            # Check if next line is separator (indicates this is header row)
            $isHeaderRow = ($i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^\|[-\s\|:]+\|$')
            
            # Clean up the line and split into cells
            $cells = ($line -replace '^\||\|$', '') -split '\|'
            $cleanCells = $cells | ForEach-Object { 
                $cell = $_.Trim()
                # Preserve existing BR tags in cells and convert markdown formatting
                $cell = $cell -replace '\*\*([^*]+)\*\*', '<strong>$1</strong>'
                $cell = $cell -replace '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2" class="external-link" rel="nofollow">$1</a>'
                # Keep BR tags as-is - they're already properly formatted for Confluence
                return $cell
            }
            
            if ($isHeaderRow) {
                # This is a header row
                $headerRow = '<tr>' + (($cleanCells | ForEach-Object { "<th class=`"confluenceTh`">$_</th>" }) -join '') + '</tr>'
                $processedLines += $headerRow
                $i++ # Skip the separator line
            } else {
                # This is a data row
                $dataRow = '<tr>' + (($cleanCells | ForEach-Object { "<td class=`"confluenceTd`">$_</td>" }) -join '') + '</tr>'
                $processedLines += $dataRow
            }
        } elseif ($line -match '^\|[-\s\|:]+\|$') {
            # Skip separator lines (already handled above)
            continue
        } else {
            if ($inTable) {
                $processedLines += '</tbody>'
                $processedLines += '</table>'
                $processedLines += '</div>'
                $inTable = $false
            }
            $processedLines += $line
        }
    }
    
    if ($inTable) {
        $processedLines += '</tbody>'
        $processedLines += '</table>'
        $processedLines += '</div>'
    }
    
    $storageContent = ($processedLines -join "`n")
    
    # Convert line breaks properly but preserve existing BR tags and table structure
    # Step 1: Convert double newlines to paragraph breaks, single newlines to BR tags
    $storageContent = $storageContent -replace "(?<!>)\r?\n\r?\n(?!<)", '<br/><br/>'
    $storageContent = $storageContent -replace "(?<!>)\r?\n(?!<)", '<br/>'
    
    # Step 2: Clean up spacing around HTML elements (preserve existing BR tags in content)
    $storageContent = $storageContent -replace '<br/><h([1-6])>', '<h$1>'
    $storageContent = $storageContent -replace '</h([1-6])><br/>', '</h$1>'
    $storageContent = $storageContent -replace '<br/><hr/>', '<hr/>'
    $storageContent = $storageContent -replace '<hr/><br/>', '<hr/>'
    $storageContent = $storageContent -replace '<br/><div', '<div'
    $storageContent = $storageContent -replace '</div><br/>', '</div>'
    $storageContent = $storageContent -replace '<br/><table>', '<table>'
    $storageContent = $storageContent -replace '</table><br/>', '</table>'
    $storageContent = $storageContent -replace '<br/><tr>', '<tr>'
    $storageContent = $storageContent -replace '</tr><br/>', '</tr>'
    
    # Clean up spacing around HTML elements
    $storageContent = $storageContent -replace '<p></p><h([1-6])>', '<h$1>'
    $storageContent = $storageContent -replace '</h([1-6])><p></p>', '</h$1>'
    $storageContent = $storageContent -replace '<p></p><hr/>', '<hr/>'
    $storageContent = $storageContent -replace '<hr/><p></p>', '<hr/>'
    $storageContent = $storageContent -replace '<p></p><div class="table-wrap">', '<div class="table-wrap">'
    $storageContent = $storageContent -replace '</div><p></p>', '</div>'
    $storageContent = $storageContent -replace '<p></p><tr>', '<tr>'
    $storageContent = $storageContent -replace '</tr><p></p>', '</tr>'
    
    # Escape HTML entities properly (avoid double-escaping)
    $storageContent = $storageContent -replace '&(?!amp;|lt;|gt;|quot;|nbsp;|#\d+;|#x[0-9a-fA-F]+;)', '&amp;'
    
    # Ensure all BR tags are self-closing for valid XHTML
    $storageContent = $storageContent -replace '<br(?!\s*/?>)', '<br/>'
    $storageContent = $storageContent -replace '<br\s*>', '<br/>'
    
    # Remove any potential malformed XML tags
    $storageContent = $storageContent -replace '<(/?)xml[^>]*>', ''
    
    Write-Log "✅ Markdown conversion completed" "Success"
    Write-Log "   Converted tables to proper HTML format" "Info"
    
    return $storageContent
}

function New-ConfluencePage {
    param([hashtable]$Headers, [string]$Title, [string]$Content, [string]$BaseUrl, [string]$Space, [string]$ParentId)
    
    Write-Log "Creating new Confluence page: '$Title'" "Info"
    
    $pageData = @{
        type = "page"
        title = $Title
        space = @{
            key = $Space
        }
        ancestors = @(
            @{
                id = $ParentId
            }
        )
        body = @{
            storage = @{
                value = $Content
                representation = "storage"
            }
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        $createUrl = "$BaseUrl/rest/api/content"
        $response = Invoke-RestMethod -Uri $createUrl -Method POST -Headers $Headers -Body $pageData
        
        Write-Log "✅ Page created successfully" "Success"
        Write-Log "   Page ID: $($response.id)" "Info"
        Write-Log "   Page URL: $BaseUrl$($response._links.webui)" "Info"
        
        return $response
    } catch {
        Write-Log "❌ Failed to create page: $($_.Exception.Message)" "Error"
        if ($_.ErrorDetails.Message) {
            $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
            Write-Log "   Error details: $($errorDetails.message)" "Error"
        }
        throw
    }
}

function Update-ConfluencePage {
    param([hashtable]$Headers, [object]$ExistingPage, [string]$Content, [string]$BaseUrl)
    
    Write-Log "Updating existing Confluence page (ID: $($ExistingPage.id))" "Info"
    
    $pageData = @{
        version = @{
            number = $ExistingPage.version.number + 1
        }
        title = $ExistingPage.title
        type = "page"
        body = @{
            storage = @{
                value = $Content
                representation = "storage"
            }
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        $updateUrl = "$BaseUrl/rest/api/content/$($ExistingPage.id)"
        $response = Invoke-RestMethod -Uri $updateUrl -Method PUT -Headers $Headers -Body $pageData
        
        Write-Log "✅ Page updated successfully" "Success"
        Write-Log "   New version: $($response.version.number)" "Info"
        Write-Log "   Page URL: $BaseUrl$($response._links.webui)" "Info"
        
        return $response
    } catch {
        Write-Log "❌ Failed to update page: $($_.Exception.Message)" "Error"
        if ($_.ErrorDetails.Message) {
            $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
            Write-Log "   Error details: $($errorDetails.message)" "Error"
        }
        throw
    }
}

function Get-WikiMetadata {
    param([string]$WikiPath)
    
    $metadataPath = Join-Path (Split-Path $WikiPath) "wiki-metadata.json"
    
    if (Test-Path $metadataPath) {
        try {
            $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
            Write-Log "✅ Loaded wiki metadata" "Success"
            Write-Log "   Rules: $($metadata.totalRules)" "Info"
            Write-Log "   Generated: $($metadata.generatedAt)" "Info"
            return $metadata
        } catch {
            Write-Log "⚠️ Failed to load metadata: $($_.Exception.Message)" "Warning"
        }
    } else {
        Write-Log "ℹ️ No metadata file found" "Info"
    }
    
    return $null
}

# Main execution
try {
    Write-Log "🚀 Starting Confluence Wiki Push" "Info"
    Write-Log "=================================" "Info"
    Write-Log "Wiki File: $WikiFilePath" "Info"
    Write-Log "Confluence: $ConfluenceUrl" "Info"
    Write-Log "Space: $SpaceKey" "Info"
    Write-Log "Parent Page: $ParentPageId" "Info"
    Write-Log "Page Title: $PageTitle" "Info"
    Write-Log "Environment: $Environment" "Info"
    Write-Log "Force Update: $ForceUpdate" "Info"
    Write-Log ""
    
    # Setup headers
    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }
    
    # Step 1: Test connectivity
    $spaceInfo = Test-ConfluenceConnectivity -Headers $headers
    
    # Step 2: Load wiki content
    $markdownContent = Read-WikiContent -FilePath $WikiFilePath
    
    # Step 3: Load metadata if available
    $metadata = Get-WikiMetadata -WikiPath $WikiFilePath
    
    # Step 4: Keep page title consistent for updates (don't enhance with metadata)
    # The metadata info is already in the content, no need to duplicate in title
    Write-Log "Using consistent page title: $PageTitle" "Info"
    if ($metadata) {
        Write-Log "   Wiki contains $($metadata.totalRules) rules (generated: $($metadata.generatedAt))" "Info"
    }
    
    # Step 5: Convert Markdown to Confluence storage format
    $confluenceContent = Convert-MarkdownToConfluenceStorage -MarkdownContent $markdownContent
    
    # Step 6: Check for existing page
    $existingPage = Get-ExistingPage -Headers $headers -Title $PageTitle -BaseUrl $ConfluenceUrl -Space $SpaceKey
    
    # Step 7: Create or update page
    if ($existingPage -and -not $ForceUpdate) {
        Write-Log "⚠️ Page exists and ForceUpdate is false - skipping update" "Warning"
        Write-Log "   Use -ForceUpdate $true to overwrite existing page" "Warning"
        exit 0
    } elseif ($existingPage) {
        $result = Update-ConfluencePage -Headers $headers -ExistingPage $existingPage -Content $confluenceContent -BaseUrl $ConfluenceUrl
        $action = "Updated"
    } else {
        $result = New-ConfluencePage -Headers $headers -Title $PageTitle -Content $confluenceContent -BaseUrl $ConfluenceUrl -Space $SpaceKey -ParentId $ParentPageId
        $action = "Created"
    }
    
    # Step 8: Final success message
    Write-Log ""
    Write-Log "🎉 Wiki push completed successfully!" "Success"
    Write-Log "=================================" "Success"
    Write-Log "Action: $action" "Info"
    Write-Log "Page ID: $($result.id)" "Info"
    Write-Log "Page Title: $($result.title)" "Info"
    Write-Log "Version: $($result.version.number)" "Info"
    Write-Log "Direct URL: $ConfluenceUrl$($result._links.webui)" "Info"
    
    if ($metadata) {
        Write-Log ""
        Write-Log "📊 Wiki Statistics:" "Info"
        Write-Log "   Total Rules: $($metadata.totalRules)" "Info"
        Write-Log "   Generated: $($metadata.generatedAt)" "Info"
        Write-Log "   Environment: $($metadata.environment)" "Info"
    }
    
    Write-Log ""
    Write-Log "✅ Push to Confluence completed successfully!" "Success"
    
} catch {
    Write-Log ""
    Write-Log "❌ Push to Confluence failed!" "Error"
    Write-Log "Error: $($_.Exception.Message)" "Error"
    
    if ($_.Exception.InnerException) {
        Write-Log "Inner Exception: $($_.Exception.InnerException.Message)" "Error"
    }
    
    Write-Log ""
    Write-Log "🔧 Troubleshooting tips:" "Info"
    Write-Log "1. Verify Confluence URL is accessible" "Info"
    Write-Log "2. Check access token permissions" "Info"
    Write-Log "3. Ensure space key exists and is accessible" "Info"
    Write-Log "4. Verify parent page ID is valid" "Info"
    Write-Log "5. Check wiki file exists and is readable" "Info"
    
    exit 1
}
