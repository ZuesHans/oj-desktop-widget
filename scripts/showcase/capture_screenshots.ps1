#requires -Version 5.1
<#
.SYNOPSIS
  Captures the three README screenshots (overview, problems, training) from the
  actually running release build, at the default window size, including the
  native window chrome.

.DESCRIPTION
  Requires the demo data to be seeded first (see seed_demo_data.ps1). For each
  page it writes window_state.json to open that page, launches the release exe,
  waits for the window and for the UI to settle, then captures the window rect
  via GetWindowRect + Graphics.CopyFromScreen.

.PARAMETER DataDir
  Application data directory. Defaults to "%APPDATA%\ZuesHans\OJ Float".

.PARAMETER ExePath
  Path to the release oj_float.exe. Defaults to the Ninja/MSBuild release path
  relative to the repository root.

.PARAMETER OutDir
  Directory for the PNG files. Defaults to "<repo>/docs/images".

.PARAMETER SettleSeconds
  How long to wait for the UI to render after the window appears.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\showcase\capture_screenshots.ps1
#>
[CmdletBinding()]
param(
    [string]$DataDir = (Join-Path $env:APPDATA 'ZuesHans\OJ Float'),
    [string]$ExePath = '',
    [string]$OutDir = '',
    [int]$SettleSeconds = 7
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'showcase_common.ps1')

if (-not $ExePath) {
    $ExePath = Join-Path $PSScriptRoot '..\..\build\windows\x64\runner\Release\oj_float.exe'
}
if (-not $OutDir) {
    $OutDir = Join-Path $PSScriptRoot '..\..\docs\images'
}
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ExePath = (Resolve-Path $ExePath).Path
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

function Write-WindowState {
    param([string]$Section)
    $state = [ordered]@{ version = 1; maximized = $false; section = $Section }
    $json = $state | ConvertTo-Json -Depth 5
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $DataDir 'window_state.json'), $json, $enc)
}

function Capture-Page {
    param(
        [string]$Name,
        [string]$Section,
        [switch]$SwitchToRecordsTab
    )
    Write-Host "Capturing '$Name' (section $Section)..."
    Stop-OjFloatProcess
    Write-WindowState -Section $Section

    $proc = Start-Process -FilePath $ExePath -PassThru
    $hwnd = Wait-ForWindow -Title 'OJ Float' -ClassName 'FLUTTER_RUNNER_WIN32_WINDOW' -TimeoutSeconds 40
    if ($hwnd -eq [IntPtr]::Zero) {
        throw "OJ Float window did not appear for section $Section"
    }
    # Let the dashboard render fully (data load + layout) before capturing.
    Start-Sleep -Seconds $SettleSeconds
    [ShowcaseWin32]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 600

    # The training page opens on its first tab; click the third tab
    # (记录与分析) to show training records. Position is expressed as a
    # fraction of the window so it stays correct across display scaling.
    if ($SwitchToRecordsTab) {
        $clickRect = Get-WindowRect -Handle $hwnd
        $clickWidth = $clickRect.Right - $clickRect.Left
        $clickHeight = $clickRect.Bottom - $clickRect.Top
        $tabX = [int]($clickRect.Left + $clickWidth * 0.85)
        $tabY = [int]($clickRect.Top + $clickHeight * 0.27)
        Click-At -X $tabX -Y $tabY
        Start-Sleep -Milliseconds 900
    }

    $rect = Get-WindowRect -Handle $hwnd
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) {
        Stop-OjFloatProcess
        throw "Invalid window rect for section ${Section}: $($rect.Left),$($rect.Top) $width x $height"
    }
    $outPath = Join-Path $OutDir "$Name.png"
    Capture-RegionPng -X $rect.Left -Y $rect.Top -Width $width -Height $height -OutPath $outPath
    Write-Host "  saved $outPath ($width x $height)"

    Stop-OjFloatProcess
}

try {
    Capture-Page -Name 'overview' -Section 'summary'
    Capture-Page -Name 'problems' -Section 'problems'
    Capture-Page -Name 'training' -Section 'training' -SwitchToRecordsTab
} finally {
    Stop-OjFloatProcess
    Write-WindowState -Section 'summary'
}

Write-Host 'Screenshot capture complete.'
