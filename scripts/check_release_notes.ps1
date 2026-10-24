param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Version
)

$ErrorActionPreference = "Stop"

# Accept either a bare version ("0.3.0") or a tag ("v0.3.0"); normalize by
# stripping a leading "v" so both resolve to docs/release-notes-vX.Y.Z.md.
$normalized = $Version
if ($normalized -match '^v(\d+\.\d+\.\d+)$') {
  $normalized = $Matches[1]
}

if ($normalized -notmatch '^\d+\.\d+\.\d+$') {
  throw "Invalid version argument '$Version'. Expected a version like '0.3.0' or a tag like 'v0.3.0'."
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$notesPath = Join-Path $repositoryRoot "docs\release-notes-v${normalized}.md"

if (-not (Test-Path -LiteralPath $notesPath -PathType Leaf)) {
  throw "Release notes are missing for v${normalized}. Create the file: $notesPath"
}

if ([string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $notesPath -Raw))) {
  throw "Release notes file is empty: $notesPath"
}

Write-Host "Release notes verified: $notesPath"
