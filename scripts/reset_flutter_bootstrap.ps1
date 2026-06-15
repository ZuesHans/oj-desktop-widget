param(
  [ValidateSet("flutter-cn", "official")]
  [string]$Mirror = "official"
)

$ErrorActionPreference = "Stop"

switch ($Mirror) {
  "flutter-cn" {
    $env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
    $env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
  }
  "official" {
    $env:PUB_HOSTED_URL = "https://pub.dev"
    $env:FLUTTER_STORAGE_BASE_URL = "https://storage.googleapis.com"
  }
}

$gitCmd = "$env:USERPROFILE\tools\Git\cmd"
$gitBin = "$env:USERPROFILE\tools\Git\bin"
$flutterBin = "$env:USERPROFILE\tools\flutter\bin"
$flutterCache = "$env:USERPROFILE\tools\flutter\bin\cache"
$projectRoot = Split-Path -Parent $PSScriptRoot

$env:Path = "$projectRoot\.tools\bin;$gitCmd;$gitBin;$flutterBin;$env:Path"
[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", $env:PUB_HOSTED_URL, "User")
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", $env:FLUTTER_STORAGE_BASE_URL, "User")

Write-Host "Cleaning interrupted Flutter bootstrap files..." -ForegroundColor Cyan
$targets = @(
  "$flutterCache\flutter.bat.lock",
  "$flutterCache\flutter_tools.snapshot",
  "$flutterCache\flutter_tools.stamp",
  "$flutterCache\flutter_tools.snapshot.old",
  "$flutterCache\flutter_tools.snapshot.old1",
  "$flutterCache\flutter_tools.snapshot.old2"
)

foreach ($target in $targets) {
  if (Test-Path $target) {
    Remove-Item $target -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "Mirror:" -ForegroundColor Cyan
Write-Host "PUB_HOSTED_URL=$env:PUB_HOSTED_URL"
Write-Host "FLUTTER_STORAGE_BASE_URL=$env:FLUTTER_STORAGE_BASE_URL"

Write-Host ""
Write-Host "Running flutter doctor..." -ForegroundColor Cyan
flutter doctor -v
