param(
  [string]$Proxy = ""
)

$ErrorActionPreference = "Continue"

$candidates = @(
  @{
    Name = "Flutter China"
    Pub = "https://pub.flutter-io.cn/api/packages/collection"
    Storage = "https://storage.flutter-io.cn/flutter_infra_release/releases/releases_windows.json"
  },
  @{
    Name = "TUNA"
    Pub = "https://mirrors.tuna.tsinghua.edu.cn/dart-pub/api/packages/collection"
    Storage = "https://mirrors.tuna.tsinghua.edu.cn/flutter/flutter_infra_release/releases/releases_windows.json"
  },
  @{
    Name = "Official"
    Pub = "https://pub.dev/api/packages/collection"
    Storage = "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
  }
)

$proxyArgs = @{}
if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
  $proxyArgs["Proxy"] = $Proxy
}

foreach ($candidate in $candidates) {
  Write-Host ""
  Write-Host "==> Testing $($candidate.Name)" -ForegroundColor Cyan
  foreach ($target in @(
    @{ Label = "pub"; Url = $candidate.Pub },
    @{ Label = "storage"; Url = $candidate.Storage }
  )) {
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      $response = Invoke-WebRequest -Uri $target.Url -Method Head -TimeoutSec 20 -UseBasicParsing @proxyArgs
      $watch.Stop()
      Write-Host "OK   $($target.Label) $($response.StatusCode) $([int]$watch.Elapsed.TotalMilliseconds)ms $($target.Url)" -ForegroundColor Green
    } catch {
      $watch.Stop()
      Write-Host "FAIL $($target.Label) $([int]$watch.Elapsed.TotalMilliseconds)ms $($target.Url)" -ForegroundColor Red
      Write-Host "     $($_.Exception.Message)"
    }
  }
}
