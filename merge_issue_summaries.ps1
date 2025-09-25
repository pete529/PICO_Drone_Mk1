param(
    [string[]]$Paths = @(),
    [string]$Glob = 'issues_summary_v2*.json',
    [string]$Output = 'issues_summary_merged_all.json',
    [switch]$IncludeDetails,
    [switch]$DryRun
)

<#!
Merge multiple issue summary JSON files (both CLI and REST variants) into a consolidated rollup.
Each input file schema may include:
 - repository
 - dryRun / updateExisting / replaceLabels / useBodyHash (REST only)
 - createdCount / updatedCount / skippedCount / failedCount / totalFromMarkdown / filteredCount
 - createdTitles / updatedTitles / skippedTitles / failedTitles
#>

if (-not $Paths -or $Paths.Count -eq 0) {
    $Paths = Get-ChildItem -File -Name $Glob | Sort-Object
}

if (-not $Paths -or $Paths.Count -eq 0) { Write-Host "No summary files found." -ForegroundColor Yellow; exit 0 }

$aggregate = [ordered]@{
    files = @()
    totalFiles = 0
    repositories = @{}
    totals = [ordered]@{
        created = 0; updated = 0; skipped = 0; failed = 0; defined = 0; filtered = 0
    }
    distinctTitles = [ordered]@{ created=@(); updated=@(); skipped=@(); failed=@() }
}

foreach ($p in $Paths) {
    if (-not (Test-Path $p)) { Write-Host "Skip missing: $p" -ForegroundColor DarkYellow; continue }
    try {
        $json = Get-Content -Raw -Path $p | ConvertFrom-Json
    } catch {
        Write-Host "Failed to parse $p -> $($_.Exception.Message)" -ForegroundColor Red; continue
    }
    $aggregate.files += $p
    $aggregate.totalFiles++
    if ($json.repository -and -not $aggregate.repositories.ContainsKey($json.repository)) { $aggregate.repositories[$json.repository] = 0 }
    if ($json.repository) { $aggregate.repositories[$json.repository]++ }

    $aggregate.totals.created += ($json.createdCount  | ForEach-Object { $_ })
    $aggregate.totals.updated += ($json.updatedCount  | ForEach-Object { $_ })
    $aggregate.totals.skipped += ($json.skippedCount  | ForEach-Object { $_ })
    $aggregate.totals.failed  += ($json.failedCount   | ForEach-Object { $_ })
    $aggregate.totals.defined += ($json.totalFromMarkdown | ForEach-Object { $_ })
    if ($json.PSObject.Properties.Name -contains 'filteredCount') { $aggregate.totals.filtered += $json.filteredCount }

    if ($IncludeDetails) {
        foreach ($t in $json.createdTitles) { if ($t -and $t -notin $aggregate.distinctTitles.created) { $aggregate.distinctTitles.created += $t } }
        foreach ($t in $json.updatedTitles) { if ($t -and $t -notin $aggregate.distinctTitles.updated) { $aggregate.distinctTitles.updated += $t } }
        foreach ($t in $json.skippedTitles) { if ($t -and $t -notin $aggregate.distinctTitles.skipped) { $aggregate.distinctTitles.skipped += $t } }
        foreach ($t in $json.failedTitles)  { if ($t -and $t -notin $aggregate.distinctTitles.failed)  { $aggregate.distinctTitles.failed  += $t } }
    }
}

$aggregate.rollup = [ordered]@{
    netCreated = $aggregate.totals.created
    netUpdated = $aggregate.totals.updated
    netSkipped = $aggregate.totals.skipped
    netFailed  = $aggregate.totals.failed
    sumDefined = $aggregate.totals.defined
    sumFiltered = $aggregate.totals.filtered
}

if ($DryRun) {
    $aggregate | ConvertTo-Json -Depth 6 | Write-Host
    exit 0
}

$aggregate | ConvertTo-Json -Depth 6 | Set-Content -Path $Output -Encoding UTF8
Write-Host ("Merged {0} files -> {1}" -f $aggregate.totalFiles,$Output) -ForegroundColor Green
