param(
    [int]$ChunkSize = 15,
    [switch]$UpdateExisting,
    [switch]$ReplaceLabels,
    [switch]$DryRun,
    [switch]$Merge,
    [string]$StoriesPath = 'user_stories.md',
    [string]$MergedSummaryPath = 'issues_summary_v2_merged.json',
    [string]$Owner,
    [string]$Repo
)

# Discover total items via dry parse (invoke v2 script with DryRun and capture summary)
$summaryTemp = Join-Path $env:TEMP "issues_summary_probe.json"
$reportTemp = Join-Path $env:TEMP "issues_report_probe.md"

Write-Host "Probing total issue count from markdown..." -ForegroundColor Cyan
# Run a dry run (no chunk) to get total count
${probeArgs} = @('-StoriesPath', $StoriesPath, '-DryRun', '-ParseOnly', '-SummaryPath', $summaryTemp, '-MarkdownReportPath', $reportTemp)
if ($Owner) { $probeArgs += @('-Owner', $Owner) }
if ($Repo) { $probeArgs += @('-Repo', $Repo) }
& powershell -NoProfile -File .\create_github_issues_v2.ps1 @probeArgs 1>$null 2>$null
if (-not (Test-Path $summaryTemp)) { Write-Host "Failed to probe summary." -ForegroundColor Red; exit 1 }
$probe = Get-Content -Path $summaryTemp -Encoding UTF8 | ConvertFrom-Json
$total = [int]$probe.totalFromMarkdown
Write-Host "Total items discovered: $total" -ForegroundColor Green

$start = 0
$chunk = 1
while ($start -lt $total) {
    Write-Host ("=== Chunk {0}: FromIndex={1} Size={2} ===" -f $chunk, $start, $ChunkSize) -ForegroundColor Magenta
    $summaryPath = "issues_summary_v2_chunk_${chunk}.json"
    $reportPath = "issues_report_v2_chunk_${chunk}.md"
    $invokeArgs = @('-StoriesPath', $StoriesPath, '-SummaryPath', $summaryPath, '-MarkdownReportPath', $reportPath, '-FromIndex', $start, '-LimitItems', $ChunkSize)
    if ($Owner) { $invokeArgs += @('-Owner', $Owner) }
    if ($Repo) { $invokeArgs += @('-Repo', $Repo) }
    if ($UpdateExisting) { $invokeArgs += '-UpdateExisting' }
    if ($ReplaceLabels) { $invokeArgs += '-ReplaceLabels' }
    if ($DryRun) { $invokeArgs += '-DryRun' }
    & powershell -NoProfile -File .\create_github_issues_v2.ps1 @invokeArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Chunk $chunk failed (exit $LASTEXITCODE). Aborting further chunks." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    $start += $ChunkSize
    $chunk++
}

Write-Host "All chunks processed successfully." -ForegroundColor Cyan

if ($Merge) {
    Write-Host "Merging chunk summaries..." -ForegroundColor Cyan
    $chunkSummaries = Get-ChildItem -File -Filter 'issues_summary_v2_chunk_*.json' | Sort-Object Name
    if ($chunkSummaries.Count -eq 0) {
        Write-Host "No chunk summary files found to merge." -ForegroundColor Yellow
    } else {
        $allCreated = New-Object System.Collections.Generic.List[string]
        $allUpdated = New-Object System.Collections.Generic.List[string]
        $allSkipped = New-Object System.Collections.Generic.List[string]
        $allFailed  = New-Object System.Collections.Generic.List[string]
        $repository = $null
        $dryRun = $false
        $updateExisting = $false
        $replaceLabels = $false
        $totalFromMarkdown = 0
        $elapsedTotal = 0
        foreach ($f in $chunkSummaries) {
            try {
                $obj = Get-Content -Path $f.FullName -Encoding UTF8 | ConvertFrom-Json
                if (-not $repository -and $obj.repository) { $repository = $obj.repository }
                if ($obj.dryRun) { $dryRun = $true }
                if ($obj.updateExisting) { $updateExisting = $true }
                if ($obj.replaceLabels) { $replaceLabels = $true }
                $totalFromMarkdown = [Math]::Max($totalFromMarkdown, [int]$obj.totalFromMarkdown)
                $elapsedTotal += [double]$obj.elapsedSeconds
                $allCreated.AddRange($obj.createdTitles) | Out-Null
                $allUpdated.AddRange($obj.updatedTitles) | Out-Null
                $allSkipped.AddRange($obj.skippedTitles) | Out-Null
                $allFailed.AddRange($obj.failedTitles) | Out-Null
            } catch {
                Write-Host "Failed to parse $($f.Name) for merge: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        $merged = [ordered]@{
            repository = $repository
            dryRun = $dryRun
            updateExisting = $updateExisting
            replaceLabels = $replaceLabels
            createdCount = $allCreated.Count
            updatedCount = $allUpdated.Count
            skippedCount = $allSkipped.Count
            failedCount = $allFailed.Count
            totalFromMarkdown = $totalFromMarkdown
            elapsedSecondsSummed = [math]::Round($elapsedTotal,1)
            uniqueCreatedCount = (@($allCreated | Select-Object -Unique)).Count
            uniqueUpdatedCount = (@($allUpdated | Select-Object -Unique)).Count
            createdTitles = @($allCreated)
            updatedTitles = @($allUpdated)
            skippedTitles = @($allSkipped)
            failedTitles = @($allFailed)
            mergedTimestampUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ssZ')
        }
        $merged | ConvertTo-Json -Depth 5 | Set-Content -Path $MergedSummaryPath -Encoding UTF8
        Write-Host "Merged summary written to $MergedSummaryPath" -ForegroundColor Green
    }
}
