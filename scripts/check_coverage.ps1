param(
  [string]$LcovPath = "coverage/lcov.info",
  [double]$OverallThreshold = 80,
  [double]$CriticalThreshold = 80
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LcovPath)) {
  throw "Coverage file not found: $LcovPath"
}

$files = @{}
$current = $null
foreach ($line in Get-Content -LiteralPath $LcovPath) {
  if ($line.StartsWith("SF:")) {
    $current = $line.Substring(3).Replace("\", "/")
    if (-not $files.ContainsKey($current)) {
      $files[$current] = @{}
    }
    continue
  }
  if ($line.StartsWith("DA:") -and $null -ne $current) {
    $parts = $line.Substring(3).Split(",")
    $lineNumber = [int]$parts[0]
    $hits = [int]$parts[1]
    if (-not $files[$current].ContainsKey($lineNumber) -or
        $hits -gt $files[$current][$lineNumber]) {
      $files[$current][$lineNumber] = $hits
    }
  }
}

function Get-Coverage([hashtable]$lines) {
  $total = $lines.Count
  $covered = @($lines.Values | Where-Object { $_ -gt 0 }).Count
  $percent = if ($total -eq 0) { 100.0 } else { 100.0 * $covered / $total }
  return [pscustomobject]@{
    Total = $total
    Covered = $covered
    Percent = $percent
  }
}

$allLines = 0
$allCovered = 0
foreach ($entry in $files.GetEnumerator()) {
  if ($entry.Key -notmatch "(^|/)lib/") {
    continue
  }
  $coverage = Get-Coverage $entry.Value
  $allLines += $coverage.Total
  $allCovered += $coverage.Covered
}
$overall = if ($allLines -eq 0) { 0 } else { 100.0 * $allCovered / $allLines }
Write-Host ("Overall coverage: {0:N1}% ({1}/{2})" -f $overall, $allCovered, $allLines)

$failures = @()
if ($overall -lt $OverallThreshold) {
  $failures += "Overall coverage $([math]::Round($overall, 1))% is below $OverallThreshold%."
}

$criticalFiles = @(
  "lib/providers/atcoder_provider.dart",
  "lib/providers/codeforces_provider.dart",
  "lib/providers/leetcode_provider.dart",
  "lib/services/local_store.dart",
  "lib/services/problem_book_service.dart",
  "lib/services/training_service.dart",
  "lib/services/browser_import_service.dart"
)

foreach ($critical in $criticalFiles) {
  $match = $files.GetEnumerator() | Where-Object {
    $_.Key.EndsWith($critical, [StringComparison]::OrdinalIgnoreCase)
  } | Select-Object -First 1
  if ($null -eq $match) {
    $failures += "Critical file is missing from coverage: $critical"
    continue
  }
  $coverage = Get-Coverage $match.Value
  Write-Host ("{0}: {1:N1}% ({2}/{3})" -f $critical, $coverage.Percent, $coverage.Covered, $coverage.Total)
  if ($coverage.Percent -lt $CriticalThreshold) {
    $failures += "$critical coverage $([math]::Round($coverage.Percent, 1))% is below $CriticalThreshold%."
  }
}

if ($failures.Count -gt 0) {
  throw ($failures -join [Environment]::NewLine)
}
