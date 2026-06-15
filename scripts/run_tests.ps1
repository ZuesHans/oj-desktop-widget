param(
  [ValidateSet("flutter-cn", "tuna", "official")]
  [string]$Mirror = "official",
  [string]$Proxy = ""
)

$ErrorActionPreference = "Stop"
switch ($Mirror) {
  "flutter-cn" {
    $env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
    $env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
  }
  "tuna" {
    $env:PUB_HOSTED_URL = "https://mirrors.tuna.tsinghua.edu.cn/dart-pub"
    $env:FLUTTER_STORAGE_BASE_URL = "https://mirrors.tuna.tsinghua.edu.cn/flutter"
  }
  "official" {
    $env:PUB_HOSTED_URL = "https://pub.dev"
    $env:FLUTTER_STORAGE_BASE_URL = "https://storage.googleapis.com"
  }
}

if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
  $env:HTTP_PROXY = $Proxy
  $env:HTTPS_PROXY = $Proxy
}
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
  $env:Path = "$projectRoot\.tools\bin;$env:USERPROFILE\tools\Git\cmd;$env:USERPROFILE\tools\Git\bin;$env:USERPROFILE\tools\flutter\bin;$env:Path"

  Write-Host "Using PUB_HOSTED_URL=$env:PUB_HOSTED_URL" -ForegroundColor Cyan
  Write-Host "Using FLUTTER_STORAGE_BASE_URL=$env:FLUTTER_STORAGE_BASE_URL" -ForegroundColor Cyan

  Write-Host ""
  Write-Host "==> flutter pub get" -ForegroundColor Cyan
  flutter pub get

  Write-Host ""
  Write-Host "==> flutter analyze" -ForegroundColor Cyan
  flutter analyze

  Write-Host ""
  Write-Host "==> flutter test" -ForegroundColor Cyan
  flutter test
} finally {
  Pop-Location
}
