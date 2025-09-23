param(
    [string]$Owner,
    [string]$Repo,
    [string]$StoriesPath = "user_stories.md",
    [switch]$UpdateExisting,
    [switch]$ReplaceLabels,
    [switch]$DryRun,
    [string]$SummaryPath = "issues_summary_v2.json",
    [string]$MarkdownReportPath = "issues_report_v2.md",
    [string]$GitHubToken
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

    try {
        $status = gh auth status 2>$null
        if ($LASTEXITCODE -ne 0) { throw "gh not authenticated" }
        Write-Host "GitHub CLI authenticated." -ForegroundColor Green
    } catch {
        Write-Host "GitHub CLI not authenticated; please run 'gh auth login' or provide GH_TOKEN." -ForegroundColor Yellow
        throw
    }
}

function Resolve-Repo {
    param([string]$Owner,[string]$Repo)
    if ($Owner -and $Repo) { return @{ Owner=$Owner; Repo=$Repo } }
    $info = gh repo view --json nameWithOwner | ConvertFrom-Json
    if (-not $info -or -not $info.nameWithOwner) { throw "Unable to resolve current repo. Pass -Owner and -Repo." }
    $parts = $info.nameWithOwner -split "/"
    return @{ Owner=$parts[0]; Repo=$parts[1] }
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
        if ($line -match '^\s*(#{1,6})\s+(.*)$') {
            $level = $matches[1].Length
            $text = $matches[2].Trim()

            # Only treat levels 1-3 as issues; others go into body
            if ($level -le 3) {
                # Finish previous
                FlushCurrent

                $labels = Parse-LabelsFromText -text $text
                $title = Strip-LabelsTag -text $text

                $typeLabel = switch ($level) {
                    1 { 'Epic' }
                    2 { 'Feature' }
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
    foreach ($it in $issues) { $it.Remove('level') | Out-Null }
    return ,$issues
}

function Get-ExistingIssuesMap {
    param([string]$Owner,[string]$Repo)
    $raw = gh issue list --repo "$Owner/$Repo" --state all --limit 1000 --json number,title,labels 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Failed to list issues for $Owner/$Repo" }
    $list = $raw | ConvertFrom-Json
    $map = @{}
    foreach ($it in $list) { $map[$it.title] = $it }
    return $map
}

function Ensure-Labels {
    param([string]$Owner,[string]$Repo,[string[]]$labels)
    if (-not $labels -or $labels.Count -eq 0) { return }
    $existing = gh label list --repo "$Owner/$Repo" --limit 1000 --json name 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty name
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
    gh issue edit $number --repo "$Owner/$Repo" --body-file "$tmp" 1>$null
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

    foreach ($l in $toAdd) {
        if ($DryRun) { Write-Host "DRYRUN add label '$l' to #$number" -ForegroundColor DarkGray }
        else { gh issue edit $number --repo "$Owner/$Repo" --add-label "$l" 1>$null }
    }
    foreach ($l in $toRemove) {
        if ($DryRun) { Write-Host "DRYRUN remove label '$l' from #$number" -ForegroundColor DarkGray }
        else { gh issue edit $number --repo "$Owner/$Repo" --remove-label "$l" 1>$null }
    }
}

# Main
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Ensure-GhAuth
    $repo = Resolve-Repo -Owner $Owner -Repo $Repo
    $Owner = $repo.Owner; $Repo = $repo.Repo
    if (-not (Test-Path -Path $StoriesPath)) { throw "Stories file not found: $StoriesPath" }
    $lines = Get-Content -Path $StoriesPath -Encoding UTF8

    Write-Host "Parsing $StoriesPath..." -ForegroundColor Green
    $desiredIssues = Parse-Stories -lines $lines
    Write-Host ("Found {0} items to sync from markdown" -f $desiredIssues.Count) -ForegroundColor Cyan

    # Collect all labels to ensure they exist
    $allLabels = @()
    foreach ($d in $desiredIssues) { $allLabels += $d.labels }
    $allLabels = @($allLabels | Where-Object { $_ } | Select-Object -Unique)
    Ensure-Labels -Owner $Owner -Repo $Repo -labels $allLabels

    $existingMap = Get-ExistingIssuesMap -Owner $Owner -Repo $Repo

    $created = New-Object System.Collections.Generic.List[string]
    $updated = New-Object System.Collections.Generic.List[string]
    $skipped = New-Object System.Collections.Generic.List[string]

    foreach ($d in $desiredIssues) {
        if ($existingMap.ContainsKey($d.title)) {
            $ex = $existingMap[$d.title]
            if ($UpdateExisting) {
                Write-Host "Updating: $($d.title) (#$($ex.number))" -ForegroundColor Cyan
                if (-not $DryRun) {
                    Set-IssueBody -number $ex.number -Owner $Owner -Repo $Repo -body $d.body
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
                gh issue create --repo "$Owner/$Repo" --title "$($d.title)" --body-file "$tmp" @labelArgs 1>$null
            }
            $created.Add($d.title) | Out-Null
        }
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
        totalFromMarkdown = $desiredIssues.Count
        elapsedSeconds = [math]::Round($sw.Elapsed.TotalSeconds,1)
        createdTitles = @($created)
        updatedTitles = @($updated)
        skippedTitles = @($skipped)
    }
    $summary | ConvertTo-Json -Depth 5 | Set-Content -Path $SummaryPath -Encoding UTF8
    Write-Host ("Summary written to {0}" -f $SummaryPath) -ForegroundColor Green

    # Markdown report
    if ($MarkdownReportPath) {
        $md = @()
        $md += "# Issue Sync Report"
        $md += "Repository: $Owner/$Repo"
        $md += "Run Timestamp: $(Get-Date -AsUTC -Format 'yyyy-MM-dd HH:mm:ss')Z"
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
