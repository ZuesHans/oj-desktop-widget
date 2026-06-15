param(
  [string]$FlutterParent = "$env:USERPROFILE\tools",
  [switch]$InstallVisualStudioBuildTools,
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
  [Environment]::SetEnvironmentVariable("HTTP_PROXY", $Proxy, "User")
  [Environment]::SetEnvironmentVariable("HTTPS_PROXY", $Proxy, "User")
}

function Write-Step($Message) {
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ensure-Command($Name, $InstallCommand) {
  if (Get-Command $Name -ErrorAction SilentlyContinue) {
    Write-Host "$Name already available."
    return
  }

  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "$Name is missing and winget is not available. Please install $Name manually, then rerun this script."
  }

  Invoke-Expression $InstallCommand
}

Write-Step "Installing Git if needed"
Ensure-Command "git" "winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements"

Write-Step "Installing Flutter SDK if needed"
$flutterDir = Join-Path $FlutterParent "flutter"
if (-not (Test-Path $flutterDir)) {
  New-Item -ItemType Directory -Force -Path $FlutterParent | Out-Null
  git clone -b stable https://github.com/flutter/flutter.git $flutterDir
}

$flutterBin = Join-Path $flutterDir "bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ";") -notcontains $flutterBin) {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterBin", "User")
}
$env:Path = "$env:Path;$flutterBin"

[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", $env:PUB_HOSTED_URL, "User")
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", $env:FLUTTER_STORAGE_BASE_URL, "User")

if ($InstallVisualStudioBuildTools) {
  Write-Step "Installing Visual Studio Build Tools for Flutter Windows desktop"
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget is not available on this machine, so this script cannot install Visual Studio Build Tools automatically." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please install one of these manually:" -ForegroundColor Yellow
    Write-Host "1. Visual Studio 2022 Community with workload: Desktop development with C++"
    Write-Host "2. Visual Studio 2022 Build Tools with workload: C++ build tools"
    Write-Host ""
    Write-Host "After installing it, rerun this script without -InstallVisualStudioBuildTools:" -ForegroundColor Yellow
    Write-Host "powershell -ExecutionPolicy Bypass -File .\scripts\setup_windows_env.ps1"
    throw "Visual Studio C++ build tools are required for Flutter Windows desktop."
  }
  winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget --accept-source-agreements --accept-package-agreements --override "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
}

Write-Step "Enabling Windows desktop"
flutter config --enable-windows-desktop

Write-Step "Creating missing Flutter Windows project files"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
  $env:Path = "$projectRoot\.tools\bin;$env:USERPROFILE\tools\Git\cmd;$env:USERPROFILE\tools\Git\bin;$env:USERPROFILE\tools\flutter\bin;$env:Path"
  Write-Host "Using PUB_HOSTED_URL=$env:PUB_HOSTED_URL"
  Write-Host "Using FLUTTER_STORAGE_BASE_URL=$env:FLUTTER_STORAGE_BASE_URL"

  $backup = Join-Path $env:TEMP ("oj_float_backup_" + [guid]::NewGuid())
  New-Item -ItemType Directory -Force -Path $backup | Out-Null
  Copy-Item "lib" $backup -Recurse -Force
  Copy-Item "test" $backup -Recurse -Force
  Copy-Item "pubspec.yaml" $backup -Force
  Copy-Item "analysis_options.yaml" $backup -Force

  flutter create --platforms=windows --project-name oj_float .

  Copy-Item (Join-Path $backup "lib") . -Recurse -Force
  Copy-Item (Join-Path $backup "test") . -Recurse -Force
  Copy-Item (Join-Path $backup "pubspec.yaml") . -Force
  Copy-Item (Join-Path $backup "analysis_options.yaml") . -Force

  flutter pub get
  flutter doctor -v
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "Environment setup finished. Open a new PowerShell window if flutter is not found in the current one." -ForegroundColor Green
