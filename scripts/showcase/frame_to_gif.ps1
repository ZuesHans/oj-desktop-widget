#requires -Version 5.1
<#
.SYNOPSIS
  Assembles a directory of PNG frames into an animated GIF using ffmpeg.

.DESCRIPTION
  Uses a two-pass palette (palettegen + paletteuse) so the GIF stays small and
  the text remains readable. ffmpeg is installed via:

      winget install Gyan.FFmpeg --scope user

.PARAMETER FramesDir
  Directory containing frame_0000.png, frame_0001.png, ... captured in order.

.PARAMETER OutPath
  Destination .gif path.

.PARAMETER Fps
  Playback speed in frames per second (4-8 recommended).

.PARAMETER MaxWidth
  Optional maximum width in pixels. Larger frames are downscaled proportionally.

.PARAMETER Ffmpeg
  Path to ffmpeg.exe. Defaults to the WinGet user-scope install location.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$FramesDir,
    [Parameter(Mandatory = $true)][string]$OutPath,
    [double]$Fps = 5,
    [int]$MaxWidth = 0,
    [string]$Ffmpeg = ''
)

$ErrorActionPreference = 'Stop'

if (-not $Ffmpeg) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\ffmpeg.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $Ffmpeg = $candidate
            break
        }
    }
}
if (-not $Ffmpeg -or -not (Test-Path $Ffmpeg)) {
    $fromPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($fromPath) { $Ffmpeg = $fromPath.Source } else {
        throw 'ffmpeg not found. Install with: winget install Gyan.FFmpeg --scope user'
    }
}

if (-not (Test-Path $FramesDir)) {
    throw "Frames directory not found: $FramesDir"
}

$pattern = Join-Path $FramesDir 'frame_%04d.png'
$scaleFilter = if ($MaxWidth -gt 0) { "scale='min($MaxWidth,iw)':-2:flags=lanczos" } else { 'null' }
$vf = "$scaleFilter,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer"

# Redirect ffmpeg's stderr to a log file instead of merging it with 2>&1, which
# PowerShell 5.1 (with -ErrorActionPreference Stop) turns into a NativeCommandError.
$log = Join-Path $env:TEMP 'oj-float-ffmpeg-gif.log'
$previousEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $Ffmpeg -y -framerate $Fps -i $pattern -loop 0 -vf $vf $OutPath 2>$log
} finally {
    $ErrorActionPreference = $previousEap
}
if ($LASTEXITCODE -ne 0) {
    $details = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
    throw "ffmpeg exited with code $LASTEXITCODE. $details"
}

if (-not (Test-Path $OutPath)) {
    throw "ffmpeg did not produce $OutPath"
}
$size = (Get-Item $OutPath).Length
Write-Host ("Wrote {0} ({1:N0} bytes, {2} fps)" -f $OutPath, $size, $Fps)
