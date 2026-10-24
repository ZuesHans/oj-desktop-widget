param(
  [switch]$Check
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$templatePath = Join-Path $root 'src\oj-float-importer.user.template.js'
$iconPath = Join-Path $root 'assets\pig-head-96.png'
$outputPath = Join-Path $root 'oj-float-importer.user.js'

$template = [System.IO.File]::ReadAllText($templatePath)
$iconBase64 = [Convert]::ToBase64String(
  [System.IO.File]::ReadAllBytes($iconPath)
)
$content = $template.Replace(
  '__PIG_ICON_DATA_URL__',
  "data:image/png;base64,$iconBase64"
)

if ($Check) {
  if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw 'Generated userscript is missing. Run browser_extension\tampermonkey\build.ps1.'
  }
  $existing = [System.IO.File]::ReadAllText($outputPath)
  if ($existing -cne $content) {
    throw 'Generated userscript is stale. Run browser_extension\tampermonkey\build.ps1.'
  }
  Write-Host 'Generated userscript is up to date.'
  exit 0
}

$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($outputPath, $content, $utf8WithoutBom)
Write-Host "Userscript generated: $outputPath"
