param(
    [string]$Owner,
    [string]$Repo,
    [string]$StoriesPath = 'user_stories.md',
    [switch]$UpdateExisting,
    [switch]$ReplaceLabels,
    [switch]$DryRun,
    [switch]$ParseOnly,
    [switch]$UseBodyHash,
    [string]$FilterTitle,
    [string]$GitHubToken,
    [string]$SummaryPath = 'issues_summary_v2_rest.json',
    [string]$MarkdownReportPath = 'issues_report_v2_rest.md',
    [int]$RetryCount = 5,
    [int]$InitialRetryDelayMs = 500,
    [int]$ThrottleMs = 0,
    [int]$LimitItems = 0,
    [int]$FromIndex = 0,
    [switch]$SkipUnchanged,
    [int]$HttpTimeoutSeconds = 40
)

<#
REST-based implementation that avoids gh CLI. Feature parity goals:
 - Parse markdown (Epics/Features/Stories + labels)
 - Ensure labels
 - Create missing issues
 - Update bodies (with optional SkipUnchanged) and reconcile labels (add/remove when -ReplaceLabels)
 - Chunk window: FromIndex + LimitItems
 - Retry/backoff on transient HTTP failures (>=500 or network errors, timeouts)
 - Summary JSON + optional markdown report
#>

#region Helpers
function Get-AuthHeader {
    if ($GitHubToken) { return @{ Authorization = "Bearer $GitHubToken" } }
    if ($env:GH_TOKEN) { return @{ Authorization = "Bearer $($env:GH_TOKEN)" } }
    if ($env:GITHUB_TOKEN) { return @{ Authorization = "Bearer $($env:GITHUB_TOKEN)" } }
    throw "No GitHub token provided. Use -GitHubToken or set GH_TOKEN/GITHUB_TOKEN."
}

function Invoke-GitHub {
    param(
        [Parameter(Mandatory=$true)][string]$Method,
        [Parameter(Mandatory=$true)][string]$Path,
        [object]$Body,
        [int]$Retry = $RetryCount
    )
    $base = 'https://api.github.com'
    $url = if ($Path.StartsWith('http')) { $Path } else { "$base$Path" }
    $attempt = 0
    $delay = $InitialRetryDelayMs
    while ($true) {
        $attempt++
        try {
            $headers = Get-AuthHeader
            $headers['User-Agent'] = 'mk1-rest-sync'
            $params = @{ Method = $Method; Uri = $url; Headers = $headers; TimeoutSec = $HttpTimeoutSeconds }
            if ($Body) { $json = ($Body | ConvertTo-Json -Depth 10); $params['Body'] = $json; $params['ContentType'] = 'application/json' }
            $resp = Invoke-RestMethod @params
            return $resp
        } catch {
            $isTransient = $false
            $msg = $_.Exception.Message
            if ($msg -match 'timed out' -or $msg -match 'connect' -or $msg -match '503' -or $msg -match '500') { $isTransient = $true }
            if (-not $isTransient -or $attempt -ge $Retry) { throw }
            Start-Sleep -Milliseconds $delay
            $delay = [Math]::Min($delay * 2, 8000)
        }
    }
}

function Resolve-RepoRest {
    if ($Owner -and $Repo) { return }
    # Attempt git remote origin parse
    try {
        $url = git config --get remote.origin.url 2>$null
        if ($LASTEXITCODE -eq 0 -and $url -match 'github\.com[/:]([^/]+)/([^/.]+)') {
            $script:Owner = $matches[1]; $script:Repo = $matches[2]; return
        }
    } catch {}
    throw "Unable to resolve repository automatically. Provide -Owner and -Repo."
}

function Get-LabelsFromText { param([string]$text) $labels=@(); if ($text -and $text -match '\[labels:\s*([^\]]+)\]'){ $labels += ($matches[1].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }; return ,$labels }
function Remove-LabelsTag { param([string]$text) if (-not $text){return $text}; return ($text -replace '\s*\[labels:\s*[^\]]+\]\s*',' ').Trim() }

function Get-StoriesFromFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Stories file not found: $Path" }
    $lines = Get-Content -Path $Path -Encoding UTF8
    $issues = @(); $current=$null; $pending=New-Object System.Collections.Generic.List[string]; $docTitleConsumed=$false
    function Flush { if ($current){ $current.body = ($pending -join "`n").TrimEnd(); $issues += $current; $pending.Clear() | Out-Null } }
    function IsHead([string]$t){ return ($t -match '^(Epic|Feature|Story)\b') }
    for ($i=0;$i -lt $lines.Count;$i++) {
        $line = $lines[$i]
        if ($line -match '^\s*[-*]\s*(?:\*\*)?Story\s+([0-9\.]+)(?:\*\*)?\s*:\s*(.+)$') {
            Flush
            $num=$matches[1]; $desc=$matches[2].Trim(); $issues += [ordered]@{ title = "Story ${num}: $desc"; body = $desc; labels=@('Story') }
            continue
        }
        if ($line -match '^\s*(#{1,6})\s+(.*)$') {
            $level=$matches[1].Length; $text=$matches[2].Trim()
            if (-not $docTitleConsumed -and $level -eq 1 -and -not (IsHead $text)) { $docTitleConsumed=$true; continue }
            if ($level -le 3 -and (IsHead $text)) {
                Flush
                $labels = Get-LabelsFromText $text
                $title = Remove-LabelsTag $text
                $type = if ($title -match '^Epic\b'){ 'Epic'} elseif ($title -match '^Feature\b'){ 'Feature'} else { 'Story' }
                $current = [ordered]@{ title=$title; body=''; labels=@($type)+$labels }
                continue
            }
        }
        if ($current) {
            if ($line -match '^\s*Labels?\s*:\s*(.+)$') { $more=$matches[1].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }; if ($more){ $current.labels=@($current.labels+$more|Select-Object -Unique) } } else { $pending.Add($line) }
        }
    }
    Flush
    return ,$issues
}

function Ensure-RepoLabels {
    param([string[]]$Labels)
    if (-not $Labels -or $Labels.Count -eq 0) { return }
    # List existing labels (paginate)
    $existing = @()
    $page=1
    while ($true) {
        $resp = Invoke-GitHub -Method GET -Path "/repos/$Owner/$Repo/labels?per_page=100&page=$page"
        if (-not $resp -or $resp.Count -eq 0) { break }
        $existing += ($resp | ForEach-Object { $_.name })
        if ($resp.Count -lt 100) { break }
        $page++
    }
    $toCreate = @($Labels | Where-Object { $_ -and ($_ -notin $existing) } | Select-Object -Unique)
    foreach ($l in $toCreate) {
        if ($DryRun) { Write-Host "DRYRUN create label: $l" -ForegroundColor DarkGray; continue }
        Invoke-GitHub -Method POST -Path "/repos/$Owner/$Repo/labels" -Body @{ name=$l; color='cccccc' } | Out-Null
        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
    }
}

function Get-AllIssuesMapRest {
    $issues=@(); $page=1
    while ($true) {
        $resp = Invoke-GitHub -Method GET -Path "/repos/$Owner/$Repo/issues?state=all&per_page=100&page=$page"
        if (-not $resp -or $resp.Count -eq 0) { break }
        $issues += $resp | Where-Object { -not $_.pull_request }
        if ($resp.Count -lt 100) { break }
        $page++
    }
    $byTitle=@{}; $byKey=@{}
    foreach ($it in $issues) {
        $byTitle[$it.title] = $it
        if ($it.title -match '^(Epic|Feature|Story)\s+([0-9\.]+)') {
            $k = ($matches[1]+' '+$matches[2]).ToLower()
            if (-not $byKey.ContainsKey($k)) { $byKey[$k]=$it }
        }
    }
    return @{ byTitle=$byTitle; byKey=$byKey }
}

function Update-IssueBodyRest {
    param([int]$Number,[string]$Body)
    if ($DryRun) { Write-Host "DRYRUN body update #$Number" -ForegroundColor DarkGray; return }
    Invoke-GitHub -Method PATCH -Path "/repos/$Owner/$Repo/issues/$Number" -Body @{ body=$Body } | Out-Null
}

function Sync-IssueLabelsRest {
    param([int]$Number,[object]$Existing,[string[]]$Desired)
    $desired = @($Desired | Where-Object { $_ } | Select-Object -Unique)
    $current = @()
    if ($Existing.labels) { $current = @($Existing.labels.name) }
    $toAdd = @($desired | Where-Object { $_ -notin $current })
    if ($ReplaceLabels) { $toRemove = @($current | Where-Object { $_ -notin $desired }) } else { $toRemove = @() }
    if ($DryRun) {
        foreach ($l in $toAdd) { Write-Host "DRYRUN add label '$l' to #$Number" -ForegroundColor DarkGray }
        foreach ($l in $toRemove) { Write-Host "DRYRUN remove label '$l' from #$Number" -ForegroundColor DarkGray }
        return
    }
    if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) { return }
    # GitHub API doesn't have direct add/remove in one call; we patch with full set when Replace, else add individually
    if ($ReplaceLabels) {
        Invoke-GitHub -Method PATCH -Path "/repos/$Owner/$Repo/issues/$Number" -Body @{ labels = $desired } | Out-Null
    } else {
        if ($toAdd.Count -gt 0) { Invoke-GitHub -Method PATCH -Path "/repos/$Owner/$Repo/issues/$Number" -Body @{ labels = @($current + $toAdd | Select-Object -Unique) } | Out-Null }
    }
}

function Write-RunSummaryRest {
    param($Path,$DryRun,$UpdateExisting,$ReplaceLabels,$UseBodyHash,$Created,$Updated,$Skipped,$Failed,$AllDesired,$FilteredCount,$Sw,$RepoFull)
    $summary = [ordered]@{
        repository = $RepoFull
        dryRun = [bool]$DryRun
        updateExisting = [bool]$UpdateExisting
        replaceLabels = [bool]$ReplaceLabels
        useBodyHash = [bool]$UseBodyHash
        createdCount = $Created.Count
        updatedCount = $Updated.Count
        skippedCount = $Skipped.Count
        failedCount = $Failed.Count
        totalFromMarkdown = $AllDesired.Count
        filteredCount = $FilteredCount
        elapsedSeconds = [math]::Round($Sw.Elapsed.TotalSeconds,1)
        createdTitles = @($Created)
        updatedTitles = @($Updated)
        skippedTitles = @($Skipped)
        failedTitles = @($Failed)
    }
    $summary | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
}
#endregion

#region Body Hash Helpers
function Get-CanonicalBody {
    param([string]$Body)
    if (-not $Body) { return '' }
    # Remove existing hash marker if present
    $clean = ($Body -replace '\n?<!--\s*sync-hash:[0-9a-f]{64}\s*-->','').TrimEnd()
    return $clean
}
function Get-BodyHash { param([string]$Body)
    $canon = Get-CanonicalBody -Body $Body
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($canon)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($bytes)
    ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
}
function Add-HashMarker { param([string]$Body,[string]$Hash)
    $clean = Get-CanonicalBody -Body $Body
    return ($clean + "`n<!-- sync-hash:$Hash -->")
}
function Extract-ExistingHash { param([string]$Body)
    if ($Body -match '<!--\s*sync-hash:([0-9a-f]{64})\s*-->') { return $matches[1] }
    return $null
}
#endregion

$sw=[System.Diagnostics.Stopwatch]::StartNew()
try {
    Resolve-RepoRest
    Write-Host "Using repository: $Owner/$Repo (REST)" -ForegroundColor Cyan
    $desired = Get-StoriesFromFile -Path $StoriesPath
    Write-Host ("Parsed {0} items from markdown" -f $desired.Count) -ForegroundColor Green

    $filteredCount = $desired.Count
    if ($FilterTitle) {
        try {
            $regex = [regex]::new($FilterTitle, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        } catch {
            throw "Invalid -FilterTitle regex: $FilterTitle -> $($_.Exception.Message)" }
        $desired = @($desired | Where-Object { $regex.IsMatch($_.title) })
        Write-Host ("FilterTitle applied; {0} items remain (pattern: {1})" -f $desired.Count,$FilterTitle) -ForegroundColor Yellow
    }

    if ($FromIndex -lt 0) { $FromIndex = 0 }
    if ($FromIndex -gt 0 -or $LimitItems -gt 0) {
        $origTotal = $desired.Count
        if ($FromIndex -ge $desired.Count) { Write-Host "FromIndex beyond list; nothing to process." -ForegroundColor Yellow; $desired=@() }
        else {
            if ($LimitItems -gt 0) { $end=[Math]::Min($FromIndex+$LimitItems,$desired.Count); $desired=$desired[$FromIndex..($end-1)]; Write-Host ("Window FromIndex={0} Size={1}" -f $FromIndex,$desired.Count) -ForegroundColor Magenta }
            else { $desired=$desired[$FromIndex..($desired.Count-1)]; Write-Host ("Window FromIndex={0} Size={1}" -f $FromIndex,$desired.Count) -ForegroundColor Magenta }
        }
    }

    # Apply body hashing if requested
    if ($UseBodyHash) {
        foreach ($d in $desired) {
            $hash = Get-BodyHash -Body $d.body
            $d.body = Add-HashMarker -Body $d.body -Hash $hash
            $d | Add-Member -NotePropertyName bodyHash -NotePropertyValue $hash -Force
        }
    }

    if ($ParseOnly) {
        Write-Host "ParseOnly specified; skipping API calls." -ForegroundColor Yellow
        $created = New-Object System.Collections.Generic.List[string]
        $updated = New-Object System.Collections.Generic.List[string]
        $skipped = New-Object System.Collections.Generic.List[string]
        $failed  = New-Object System.Collections.Generic.List[string]
    if ($SummaryPath) { Write-RunSummaryRest -Path $SummaryPath -DryRun:$true -UpdateExisting:$UpdateExisting -ReplaceLabels:$ReplaceLabels -UseBodyHash:$UseBodyHash -Created $created -Updated $updated -Skipped $skipped -Failed $failed -AllDesired $desired -FilteredCount $filteredCount -Sw $sw -RepoFull "$Owner/$Repo" }
        if ($MarkdownReportPath) {
            $md=@(); $md+="# Issue Sync Report (REST ParseOnly)"; $md += "Repository: $Owner/$Repo"; $utc=(Get-Date).ToUniversalTime(); $md += ("Run Timestamp: {0}Z" -f $utc.ToString('yyyy-MM-dd HH:mm:ss')); $md+="";
            $md += ("Parsed Only (no API). Items: {0}" -f $desired.Count)
            Set-Content -Path $MarkdownReportPath -Value ($md -join "`n") -Encoding UTF8
        }
        Write-Host ("Done ParseOnly in {0:n1}s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Cyan
        return
    }

    # Ensure labels (requires API)
    $allLabels = @(); foreach ($d in $desired) { $allLabels += $d.labels }
    $allLabels = @($allLabels | Where-Object { $_ } | Select-Object -Unique)
    Ensure-RepoLabels -Labels $allLabels

    $maps = Get-AllIssuesMapRest

    $created = New-Object System.Collections.Generic.List[string]
    $updated = New-Object System.Collections.Generic.List[string]
    $skipped = New-Object System.Collections.Generic.List[string]
    $failed  = New-Object System.Collections.Generic.List[string]

    $processed = 0
    foreach ($d in $desired) {
        if ($LimitItems -gt 0 -and $processed -ge $LimitItems) { break }
        $matched=$null
        if ($maps.byTitle.ContainsKey($d.title)) { $matched = $maps.byTitle[$d.title] }
        elseif ($d.title -match '^(Epic|Feature|Story)\s+([0-9\.]+)') {
            $k=($matches[1]+' '+$matches[2]).ToLower(); if ($maps.byKey.ContainsKey($k)) { $matched=$maps.byKey[$k] }
        }
        try {
            if ($matched) {
                if ($UpdateExisting) {
                    Write-Host "Updating (REST): $($d.title) (#$($matched.number))" -ForegroundColor Cyan
                    $skipBody=$false
                    if ($SkipUnchanged -and -not $DryRun) {
                        if ($UseBodyHash) {
                            $existingHash = Extract-ExistingHash -Body $matched.body
                            $newHash = if ($d.PSObject.Properties.Name -contains 'bodyHash') { $d.bodyHash } else { Get-BodyHash -Body $d.body }
                            if ($existingHash -and ($existingHash -eq $newHash)) { $skipBody=$true; Write-Host "Hash unchanged; skipping body update (#$($matched.number))" -ForegroundColor DarkGray }
                        } else {
                            $existingBody = (Get-CanonicalBody -Body $matched.body).Trim()
                            $newBodyCanon = (Get-CanonicalBody -Body $d.body).Trim()
                            if ($existingBody -eq $newBodyCanon) { $skipBody=$true; Write-Host "Body unchanged; skipping body update (#$($matched.number))" -ForegroundColor DarkGray }
                        }
                    }
                    if (-not $DryRun -and -not $skipBody) { Update-IssueBodyRest -Number $matched.number -Body $d.body }
                    Sync-IssueLabelsRest -Number $matched.number -Existing $matched -Desired $d.labels
                    $updated.Add($d.title) | Out-Null
                } else {
                    Write-Host "Skipping (exists): $($d.title)" -ForegroundColor DarkYellow
                    $skipped.Add($d.title)|Out-Null
                }
            } else {
                Write-Host "Creating (REST): $($d.title)" -ForegroundColor Green
                if (-not $DryRun) {
                    $createBody = @{ title=$d.title; body=$d.body; labels=$d.labels }
                    $resp = Invoke-GitHub -Method POST -Path "/repos/$Owner/$Repo/issues" -Body $createBody
                    # Add to maps for potential matches later
                    $maps.byTitle[$resp.title] = $resp
                    if ($resp.title -match '^(Epic|Feature|Story)\s+([0-9\.]+)') {
                        $ck=($matches[1]+' '+$matches[2]).ToLower(); if (-not $maps.byKey.ContainsKey($ck)){ $maps.byKey[$ck]=$resp }
                    }
                }
                $created.Add($d.title)|Out-Null
            }
        } catch {
            Write-Host "Failed (REST): $($d.title) -> $($_.Exception.Message)" -ForegroundColor Red
            $failed.Add($d.title)|Out-Null
        } finally {
            if ($SummaryPath) { Write-RunSummaryRest -Path $SummaryPath -DryRun:$DryRun -UpdateExisting:$UpdateExisting -ReplaceLabels:$ReplaceLabels -UseBodyHash:$UseBodyHash -Created $created -Updated $updated -Skipped $skipped -Failed $failed -AllDesired $desired -FilteredCount $filteredCount -Sw $sw -RepoFull "$Owner/$Repo" }
            if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
        }
        $processed++
    }

    $sw.Stop()
    # Final report
    if ($MarkdownReportPath) {
        $md=@(); $md+="# Issue Sync Report (REST)"; $md += "Repository: $Owner/$Repo"; $utc=(Get-Date).ToUniversalTime(); $md += ("Run Timestamp: {0}Z" -f $utc.ToString('yyyy-MM-dd HH:mm:ss')); $md+="";
        $md += ("Created: {0}  Updated: {1}  Skipped: {2}  Failed: {3}  Total From Markdown: {4}" -f $created.Count,$updated.Count,$skipped.Count,$failed.Count,$desired.Count)
        if ($created.Count -gt 0){ $md+=""; $md+="## Created"; foreach($t in $created){ $md+="- $t" } }
        if ($updated.Count -gt 0){ $md+=""; $md+="## Updated"; foreach($t in $updated){ $md+="- $t" } }
        if ($skipped.Count -gt 0){ $md+=""; $md+="## Skipped"; foreach($t in $skipped){ $md+="- $t" } }
        if ($failed.Count -gt 0){ $md+=""; $md+="## Failed"; foreach($t in $failed){ $md+="- $t" } }
        Set-Content -Path $MarkdownReportPath -Value ($md -join "`n") -Encoding UTF8
        Write-Host "Markdown report written to $MarkdownReportPath" -ForegroundColor Green
    }
    Write-Host ("Done (REST) in {0:n1}s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Cyan
} catch {
    $sw.Stop(); Write-Host "ERROR (REST): $($_.Exception.Message)" -ForegroundColor Red; exit 1
}
