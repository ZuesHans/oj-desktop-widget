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
  [Environment]::SetEnvironmentVariable("HTTP_PROXY", $Proxy, "User")
  [Environment]::SetEnvironmentVariable("HTTPS_PROXY", $Proxy, "User")
}

$gitCmd = "$env:USERPROFILE\tools\Git\cmd"
$gitBin = "$env:USERPROFILE\tools\Git\bin"
$flutterBin = "$env:USERPROFILE\tools\flutter\bin"
$projectRoot = Split-Path -Parent $PSScriptRoot
$projectToolsBin = "$projectRoot\.tools\bin"
$flutterCache = "$env:USERPROFILE\tools\flutter\bin\cache"
$lockFile = Join-Path $flutterCache "flutter.bat.lock"

if (Test-Path $lockFile) {
  Remove-Item $lockFile -Force
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($pathItem in @($gitCmd, $gitBin, $flutterBin)) {
  if ((Test-Path $pathItem) -and (($userPath -split ";") -notcontains $pathItem)) {
    $userPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $pathItem } else { "$userPath;$pathItem" }
  }
}
[Environment]::SetEnvironmentVariable("Path", $userPath, "User")
[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", $env:PUB_HOSTED_URL, "User")
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", $env:FLUTTER_STORAGE_BASE_URL, "User")
$env:Path = "$projectToolsBin;$gitCmd;$gitBin;$flutterBin;$env:Path"

Write-Host "Git:" -ForegroundColor Cyan
git --version

Write-Host ""
Write-Host "Mirror:" -ForegroundColor Cyan
Write-Host "PUB_HOSTED_URL=$env:PUB_HOSTED_URL"
Write-Host "FLUTTER_STORAGE_BASE_URL=$env:FLUTTER_STORAGE_BASE_URL"
if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
  Write-Host "Proxy=$Proxy"
}

Write-Host ""
Write-Host "Flutter doctor:" -ForegroundColor Cyan
flutter doctor -v

Write-Host ""
Write-Host "Flutter environment repaired. Please open a new PowerShell window before running tests." -ForegroundColor Green
