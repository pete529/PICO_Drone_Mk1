param(
    [string]$Owner,
    [string]$Repo,
    [string]$StoriesPath = "user_stories.md",
    [switch]$UpdateExisting,
    [switch]$ReplaceLabels,
    [switch]$DryRun,
    [string]$SummaryPath = "issues_summary_v2.json",
    [string]$MarkdownReportPath = "issues_report_v2.md",
    [string]$GitHubToken,
    [int]$RetryCount = 5,
    [int]$InitialRetryDelayMs = 500,
    [int]$ThrottleMs = 0,
    [int]$LimitItems = 0,
    [int]$GhTimeoutSeconds = 60,
    [switch]$SkipUnchanged,
    [int]$FromIndex = 0,
    [switch]$ParseOnly
)

# v2: Parse Markdown (Epics/Features/Stories) and create/update GitHub issues idempotently
# - Headings: # Epic, ## Feature, ### Story
# - Optional labels: [labels: a, b] in heading OR a line starting with "Labels:" in the body block
# - Auto-apply type labels: Epic | Feature | Story
# - If -UpdateExisting: update body; add labels; if -ReplaceLabels: reconcile to match exactly
# - -DryRun: print planned actions without changing repo
# - Auth: uses existing gh session; if -GitHubToken or env GH_TOKEN/GITHUB_TOKEN present, sets env for gh

function Ensure-GhAuth {
    param()
    $envToken = $null
    if ($GitHubToken) { $envToken = $GitHubToken }
    elseif ($env:GH_TOKEN) { $envToken = $env:GH_TOKEN }
    elseif ($env:GITHUB_TOKEN) { $envToken = $env:GITHUB_TOKEN }

    if ($envToken) { $env:GH_TOKEN = $envToken }
    [string]$FilterTitle,

    try {
        $status = gh auth status 2>$null
        if ($LASTEXITCODE -ne 0) { throw "gh not authenticated" }
        Write-Host "GitHub CLI authenticated." -ForegroundColor Green
    } catch {
        Write-Host "GitHub CLI not authenticated; please run 'gh auth login' or provide GH_TOKEN." -ForegroundColor Yellow
        throw
    }
}

function Invoke-GhSafe {
    param(
        [Parameter(Mandatory=$true)][string]$CommandLine,
        [switch]$IgnoreErrors,
        [int]$RetryCountParam = $RetryCount,
        [int]$TimeoutSeconds = $GhTimeoutSeconds
    )
    $attempt = 0
    $delay = $InitialRetryDelayMs
    while ($true) {
        $attempt++
        $code = $null
        $timedOut = $false
        try {
            # Use explicit process control for timeout handling
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'cmd.exe'
            $psi.Arguments = "/c $CommandLine"
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $proc = [System.Diagnostics.Process]::Start($psi)
            if ($TimeoutSeconds -gt 0) {
                if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                    $timedOut = $true
                    try { $proc.Kill() | Out-Null } catch {}
                }
            } else {
                $proc.WaitForExit() | Out-Null
            }
            if (-not $timedOut) { $code = $proc.ExitCode } else { $code = -999 }
        } catch {
            $code = -998
        }
        if ($code -eq 0) { return $true }
        $transient = $false
        # Treat non-zero (including timeout sentinel) as transient for retry purposes
        if ($code -ne 0) { $transient = $true }
        if ($timedOut) { Write-Host "gh command timed out after ${TimeoutSeconds}s: $CommandLine" -ForegroundColor DarkYellow }
        if (-not $transient -or $attempt -ge $RetryCountParam) {
            if (-not $IgnoreErrors) { throw "gh failed (exit $code) after $attempt attempts: $CommandLine" }
            return $false
        }
        Start-Sleep -Milliseconds $delay
        $delay = [Math]::Min($delay * 2, 8000)
    }
}

function Resolve-Repo {
    param([string]$Owner,[string]$Repo)
    if ($Owner -and $Repo) { return @{ Owner=$Owner; Repo=$Repo } }
    # Primary: gh repo view
    try {
            $infoRaw = & gh repo view --json nameWithOwner 2>$null
        if ($LASTEXITCODE -eq 0 -and $infoRaw) {
            $info = $infoRaw | ConvertFrom-Json
            if ($info -and $info.nameWithOwner) {
                $parts = $info.nameWithOwner -split "/"
                if ($parts.Length -eq 2 -and $parts[0] -and $parts[1]) { return @{ Owner=$parts[0]; Repo=$parts[1] } }
            }
        }
    } catch {}

    # Fallback: parse git remote origin url
    try {
        $url = git config --get remote.origin.url 2>$null
        if ($LASTEXITCODE -eq 0 -and $url) {
            # Support https and ssh forms
            if ($url -match 'github\.com[/:]([^/]+)/([^/.]+)') {
                $o = $matches[1]; $r = $matches[2]
                if ($o -and $r) { return @{ Owner=$o; Repo=$r } }
            }
        }
    } catch {}

    throw "Unable to resolve current repo. Pass -Owner and -Repo."
}

function Parse-LabelsFromText {
    param([string]$text)
    $labels = @()
    if (-not [string]::IsNullOrEmpty($text)) {
        if ($text -match "\[labels:\s*([^\]]+)\]") {
            $labels += ($matches[1].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
            # strip from title text
        }
    }
    return ,$labels
}

function Strip-LabelsTag {
    param([string]$text)
    if (-not $text) { return $text }
    return ($text -replace "\s*\[labels:\s*[^\]]+\]\s*"," ").Trim()
}

function Parse-Stories {
    param([string[]]$lines)
    $issues = @()
    $current = $null
    $currentLevel = 0
    $pendingBody = New-Object System.Collections.Generic.List[string]
    $docTitleConsumed = $false

    function Is-HeadingIssueText([string]$text) {
        return ($text -match '^(Epic|Feature|Story)\b')
    }

    function FlushCurrent() {
        if ($null -ne $current) {
            $body = ($pendingBody -join "`n").TrimEnd()
            $current.body = $body
            $issues += $current
            $pendingBody.Clear() | Out-Null
        }
    }

    for ($i=0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Globally detect bullet-style Story items: "- **Story X.Y.Z**: description"
        if ($line -match '^\s*[-*]\s*(?:\*\*)?Story\s+([0-9\.]+)(?:\*\*)?\s*:\s*(.+)$') {
            $num = $matches[1]
            $desc = $matches[2].Trim()
            $title = "Story ${num}: $desc"
            # Finish any pending current item before adding a standalone story
            FlushCurrent
            $issues += [ordered]@{
                title = $title
                body = $desc
                labels = @('Story')
            }
            continue
        }
        if ($line -match '^\s*(#{1,6})\s+(.*)$') {
            $level = $matches[1].Length
            $text = $matches[2].Trim()

            # Skip a top-level document title that isn't an issue heading
            if (-not $docTitleConsumed -and $level -eq 1 -and -not (Is-HeadingIssueText $text)) {
                $docTitleConsumed = $true
                continue
            }

            # Only treat levels 1-3 as issues and only if text starts with Epic/Feature/Story
            if ($level -le 3 -and (Is-HeadingIssueText $text)) {
                FlushCurrent

                $labels = Parse-LabelsFromText -text $text
                $title = Strip-LabelsTag -text $text

                $typeLabel = switch -Regex ($title) {
                    '^Epic\b' { 'Epic'; break }
                    '^Feature\b' { 'Feature'; break }
                    default { 'Story' }
                }

                $current = [ordered]@{
                    title = $title
                    body = ''
                    labels = @($typeLabel) + $labels
                    level = $level
                }
                $currentLevel = $level
                continue
            }
        }

        if ($null -ne $current) {
            # Capture body; also detect a standalone Labels: line
            if ($line -match '^\s*Labels?\s*:\s*(.+)$') {
                $more = $matches[1].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                if ($more) { $current.labels = @($current.labels + $more | Select-Object -Unique) }
            } else {
                $pendingBody.Add($line)
            }
        }
    }
    FlushCurrent
    # Remove helper property
    foreach ($it in $issues) { if ($it.Contains('level')) { $it.Remove('level') | Out-Null } }
    return ,$issues
}

function Get-ExistingIssuesMap {
    param([string]$Owner,[string]$Repo)
        if (-not $Owner -or -not $Repo) { throw "Missing Owner/Repo for listing issues" }
    $raw = gh issue list --repo "$Owner/$Repo" --state all --limit 1000 --json number,title,labels 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Failed to list issues for $Owner/$Repo" }
    $list = $raw | ConvertFrom-Json
    $byTitle = @{}
    $byKey = @{}
    foreach ($it in $list) {
        $byTitle[$it.title] = $it
        # Extract a leading key like 'Epic 1', 'Feature 1.2', 'Story 1.2.3'
        if ($it.title -match '^(Epic|Feature|Story)\s+([0-9\.]+)') {
            $key = ($matches[1] + ' ' + $matches[2]).ToLower()
            if (-not $byKey.ContainsKey($key)) { $byKey[$key] = $it }
        }
    }
    return @{ byTitle = $byTitle; byKey = $byKey }
}

function Ensure-Labels {
    param([string]$Owner,[string]$Repo,[string[]]$labels)
    if (-not $labels -or $labels.Count -eq 0) { return }
    $existing = @()
    $existingRaw = & gh label list --repo "$Owner/$Repo" --limit 1000 --json name 2>$null
    if ($LASTEXITCODE -eq 0 -and $existingRaw) {
        try {
            $obj = $existingRaw | ConvertFrom-Json
            if ($obj -is [System.Collections.IEnumerable]) {
                foreach ($x in $obj) {
                    if ($null -eq $x) { continue }
                    $props = $x.PSObject.Properties.Name
                    if ($props -and ($props -contains 'name')) { $existing += $x.name }
                    elseif ($x -is [string]) { $existing += $x }
                }
            }
        } catch {
            # ignore parse errors; treat as none existing
        }
    }
    $toCreate = @($labels | Where-Object { $_ -and ($_ -notin $existing) } | Select-Object -Unique)
    foreach ($l in $toCreate) {
        if ($DryRun) { Write-Host "DRYRUN create label: $l" -ForegroundColor DarkGray; continue }
        gh label create "$l" --repo "$Owner/$Repo" --color "cccccc" 1>$null 2>$null
    }
}

function Set-IssueBody {
    param([int]$number,[string]$Owner,[string]$Repo,[string]$body)
    $tmp = [System.IO.Path]::Combine($env:TEMP, "issue_body_$number.md")
    Set-Content -Path $tmp -Value $body -Encoding UTF8
    Invoke-GhSafe -CommandLine "gh issue edit $number --repo $Owner/$Repo --body-file `"$tmp`"" | Out-Null
}

function Reconcile-Labels {
    param([int]$number,[string]$Owner,[string]$Repo,[string[]]$desired,[object]$existingIssue)
    $existing = @()
    if ($existingIssue -and $existingIssue.labels) { $existing = @($existingIssue.labels.name) }
    $desired = @($desired | Where-Object { $_ -ne '' } | Select-Object -Unique)

    $toAdd = @($desired | Where-Object { $_ -notin $existing })
    if ($ReplaceLabels) {
        $toRemove = @($existing | Where-Object { $_ -notin $desired })
    } else {
        $toRemove = @()
    }

    if ($DryRun) {
        foreach ($l in $toAdd) { Write-Host "DRYRUN add label '$l' to #$number" -ForegroundColor DarkGray }
        foreach ($l in $toRemove) { Write-Host "DRYRUN remove label '$l' from #$number" -ForegroundColor DarkGray }
        return
    }
    if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) { return }
    $args = @("issue","edit", "$number", "--repo", "$Owner/$Repo")
    foreach ($l in $toAdd) { $args += @("--add-label", $l) }
    foreach ($l in $toRemove) { $args += @("--remove-label", $l) }
    $escaped = $args | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    Invoke-GhSafe -CommandLine ("gh " + ($escaped -join ' ')) | Out-Null
}

function Write-RunSummary {
    param(
        [string]$Path,
        [string]$Owner,
        [string]$Repo,
        [switch]$DryRun,
        [switch]$UpdateExisting,
        [switch]$ReplaceLabels,
        $created,
        $updated,
        $skipped,
        $failed,
        $desiredIssues,
        $sw
    )
    try {
        $summary = [ordered]@{
            repository = "$Owner/$Repo"
            dryRun = [bool]$DryRun
            updateExisting = [bool]$UpdateExisting
            replaceLabels = [bool]$ReplaceLabels
            createdCount = $created.Count
            updatedCount = $updated.Count
            skippedCount = $skipped.Count
            failedCount = $failed.Count
            totalFromMarkdown = $desiredIssues.Count
            filteredCount = $desiredIssues.Count
            elapsedSeconds = [math]::Round($sw.Elapsed.TotalSeconds,1)
            createdTitles = @($created)
            updatedTitles = @($updated)
            skippedTitles = @($skipped)
            failedTitles = @($failed)
        }
        $summary | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
    } catch {
        # ignore
    }
}

# Main
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    if (-not $ParseOnly) { Ensure-GhAuth }
    if (-not $ParseOnly) {
        if (-not $Owner -or -not $Repo) {
            $repo = Resolve-Repo -Owner $Owner -Repo $Repo
            $Owner = $repo.Owner; $Repo = $repo.Repo
        }
        Write-Host "Using repository: $Owner/$Repo" -ForegroundColor DarkCyan
    } else {
        # For parse-only mode set placeholder repo for summary clarity
        if (-not $Owner) { $Owner = 'N/A' }
        if (-not $Repo) { $Repo = 'N/A' }
    }
    if (-not (Test-Path -Path $StoriesPath)) { throw "Stories file not found: $StoriesPath" }
    $lines = Get-Content -Path $StoriesPath -Encoding UTF8

    Write-Host "Parsing $StoriesPath..." -ForegroundColor Green
    $desiredIssues = Parse-Stories -lines $lines
    Write-Host ("Found {0} items to sync from markdown" -f $desiredIssues.Count) -ForegroundColor Cyan
    $filteredCount = $desiredIssues.Count
    if ($FilterTitle) {
        try { $regex = [regex]::new($FilterTitle, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) } catch { throw "Invalid -FilterTitle regex: $FilterTitle -> $($_.Exception.Message)" }
        $desiredIssues = @($desiredIssues | Where-Object { $regex.IsMatch($_.title) })
        Write-Host ("FilterTitle applied; {0} items remain (pattern: {1})" -f $desiredIssues.Count,$FilterTitle) -ForegroundColor Yellow
    }

    # Apply chunk window if FromIndex/LimitItems specified
    if ($FromIndex -lt 0) { $FromIndex = 0 }
    if ($FromIndex -gt 0 -or $LimitItems -gt 0) {
        $originalTotal = $desiredIssues.Count
        if ($FromIndex -ge $desiredIssues.Count) {
            Write-Host "FromIndex $FromIndex beyond list (total $originalTotal). Nothing to do." -ForegroundColor Yellow
            $desiredIssues = @()
        } else {
            if ($LimitItems -gt 0) {
                $endExclusive = [Math]::Min($FromIndex + $LimitItems, $desiredIssues.Count)
                $desiredIssues = $desiredIssues[$FromIndex..($endExclusive-1)]
                Write-Host ("Processing chunk: start={0} size={1} end={2} of total {3}" -f $FromIndex, $desiredIssues.Count, ($FromIndex + $desiredIssues.Count - 1), $originalTotal) -ForegroundColor Magenta
            } else {
                $desiredIssues = $desiredIssues[$FromIndex..($desiredIssues.Count-1)]
                Write-Host ("Processing from index {0} to end (size {1} of total {2})" -f $FromIndex, $desiredIssues.Count, $originalTotal) -ForegroundColor Magenta
            }
        }
    }

    if (-not $ParseOnly) {
        # Collect all labels to ensure they exist
        $allLabels = @()
        foreach ($d in $desiredIssues) { $allLabels += $d.labels }
        $allLabels = @($allLabels | Where-Object { $_ } | Select-Object -Unique)
        Ensure-Labels -Owner $Owner -Repo $Repo -labels $allLabels

        $existingMaps = Get-ExistingIssuesMap -Owner $Owner -Repo $Repo
    } else {
        $existingMaps = @{ byTitle = @{}; byKey = @{} }
    }

    $created = New-Object System.Collections.Generic.List[string]
    $updated = New-Object System.Collections.Generic.List[string]
    $skipped = New-Object System.Collections.Generic.List[string]
    $failed  = New-Object System.Collections.Generic.List[string]

    $processed = 0
    foreach ($d in $desiredIssues) {
        $matched = $null
        if ($existingMaps.byTitle.ContainsKey($d.title)) {
            $matched = $existingMaps.byTitle[$d.title]
        } elseif ($d.title -match '^(Epic|Feature|Story)\s+([0-9\.]+)') {
            $k = ($matches[1] + ' ' + $matches[2]).ToLower()
            if ($existingMaps.byKey.ContainsKey($k)) { $matched = $existingMaps.byKey[$k] }
        }

        try {
            if ($ParseOnly) {
                # In parse only we just record as skipped placeholder
                $skipped.Add($d.title) | Out-Null
            } elseif ($matched) {
                $ex = $matched
                if ($UpdateExisting) {
                    Write-Host "Updating: $($d.title) (#$($ex.number))" -ForegroundColor Cyan
                    $skipBody = $false
                    if ($SkipUnchanged -and -not $DryRun) {
                        # Fetch existing body only when needed
                        $detailRaw = gh issue view $ex.number --repo $Owner/$Repo --json body 2>$null
                        if ($LASTEXITCODE -eq 0 -and $detailRaw) {
                            try {
                                $detail = $detailRaw | ConvertFrom-Json
                                if ($detail -and $detail.body) {
                                    $existingBody = ($detail.body.Trim())
                                    $newBody = ($d.body.Trim())
                                    if ($existingBody -eq $newBody) {
                                        $skipBody = $true
                                        Write-Host "Body unchanged; skipping body update for #$($ex.number)" -ForegroundColor DarkGray
                                    }
                                }
                            } catch {}
                        }
                    }
                    if (-not $DryRun) {
                        if (-not $skipBody) { Set-IssueBody -number $ex.number -Owner $Owner -Repo $Repo -body $d.body }
                        Reconcile-Labels -number $ex.number -Owner $Owner -Repo $Repo -desired $d.labels -existingIssue $ex
                    }
                    $updated.Add($d.title) | Out-Null
                } else {
                    Write-Host "Skipping (exists): $($d.title)" -ForegroundColor DarkYellow
                    $skipped.Add($d.title) | Out-Null
                }
            } else {
                Write-Host "Creating: $($d.title)" -ForegroundColor Green
                if (-not $DryRun) {
                    $labelArgs = @()
                    foreach ($l in $d.labels) { $labelArgs += @('--label', $l) }
                    $tmp = [System.IO.Path]::Combine($env:TEMP, "issue_body_create.md")
                    Set-Content -Path $tmp -Value $d.body -Encoding UTF8
                    $cmd = @('gh','issue','create','--repo',"$Owner/$Repo",'--title',"$($d.title)",'--body-file',"$tmp") + $labelArgs
                    $escaped = $cmd | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
                    Invoke-GhSafe -CommandLine ($escaped -join ' ') | Out-Null
                }
                $created.Add($d.title) | Out-Null
            }
        } catch {
            $msg = $_.Exception.Message
            Write-Host "Failed: $($d.title) -> $msg" -ForegroundColor Red
            $failed.Add($d.title) | Out-Null
            continue
        } finally {
            if ($SummaryPath) {
                Write-RunSummary -Path $SummaryPath -Owner $Owner -Repo $Repo -DryRun:$DryRun -UpdateExisting:$UpdateExisting -ReplaceLabels:$ReplaceLabels -created $created -updated $updated -skipped $skipped -failed $failed -desiredIssues $desiredIssues -sw $sw
            }
            if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
        }
        $processed++
    }

    $sw.Stop()

    # Summary JSON
    $summary = [ordered]@{
        repository = "$Owner/$Repo"
        dryRun = [bool]$DryRun
        updateExisting = [bool]$UpdateExisting
        replaceLabels = [bool]$ReplaceLabels
        createdCount = $created.Count
        updatedCount = $updated.Count
        skippedCount = $skipped.Count
        failedCount = $failed.Count
        totalFromMarkdown = $desiredIssues.Count
        filteredCount = $desiredIssues.Count
        elapsedSeconds = [math]::Round($sw.Elapsed.TotalSeconds,1)
        createdTitles = @($created)
        updatedTitles = @($updated)
        skippedTitles = @($skipped)
        failedTitles = @($failed)
    }
    $summary | ConvertTo-Json -Depth 5 | Set-Content -Path $SummaryPath -Encoding UTF8
    Write-Host ("Summary written to {0}" -f $SummaryPath) -ForegroundColor Green

    # Markdown report
    if ($MarkdownReportPath -and -not $ParseOnly) {
        $md = @()
        $md += "# Issue Sync Report"
        $md += "Repository: $Owner/$Repo"
        $utc = (Get-Date).ToUniversalTime()
        $md += ("Run Timestamp: {0}Z" -f $utc.ToString('yyyy-MM-dd HH:mm:ss'))
        $md += ""
        $md += ("Created: {0}  Updated: {1}  Skipped: {2}  Total From Markdown: {3}" -f $created.Count, $updated.Count, $skipped.Count, $desiredIssues.Count)
        $md += ""
        if ($created.Count -gt 0) {
            $md += "## Created Issues"
            foreach ($t in $created) { $md += "- $t" }
            $md += ""
        }
        if ($updated.Count -gt 0) {
            $md += "## Updated Issues"
            foreach ($t in $updated) { $md += "- $t" }
            $md += ""
        }
        if ($skipped.Count -gt 0) {
            $md += "## Skipped (Already Existed)"
            foreach ($t in $skipped) { $md += "- $t" }
            $md += ""
        }
        Set-Content -Path $MarkdownReportPath -Value ($md -join "`n") -Encoding UTF8
        Write-Host "Markdown report written to $MarkdownReportPath" -ForegroundColor Green
    }

    Write-Host ("Done in {0:n1}s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Cyan

} catch {
    $sw.Stop()
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
