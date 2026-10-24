#requires -Version 5.1
<#
.SYNOPSIS
  Records the ~10s "browser problem page -> one-click save -> problem appears in
  the client" demo as docs/images/demo.gif.

.DESCRIPTION
  Script-driven demo (no real browser extension). It launches the seeded client
  on the problem book, opens a local mock problem page in the default browser,
  positions the two windows side by side, captures PNG frames, and POSTs one
  fabricated problem to the client's loopback import endpoint (127.0.0.1:27121)
  to simulate the extension's one-click save. The frames are assembled into an
  animated GIF by frame_to_gif.ps1 (ffmpeg).

.PARAMETER DataDir
  Application data directory. Defaults to "%APPDATA%\ZuesHans\OJ Float".

.PARAMETER ExePath
  Path to the release oj_float.exe.

.PARAMETER OutPath
  Destination .gif path. Defaults to "<repo>/docs/images/demo.gif".

.PARAMETER Fps
  Capture/playback frame rate (4-8 recommended).

.PARAMETER DurationSeconds
  Total recording length in seconds.

.PARAMETER MaxWidth
  Max GIF width in pixels; larger frames are downscaled.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\showcase\record_demo.ps1
#>
[CmdletBinding()]
param(
    [string]$DataDir = (Join-Path $env:APPDATA 'ZuesHans\OJ Float'),
    [string]$ExePath = '',
    [string]$OutPath = '',
    [double]$Fps = 5,
    [int]$DurationSeconds = 12,
    [int]$MaxWidth = 1100
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'showcase_common.ps1')

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class DemoWin32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll")] public static extern IntPtr GetShellWindow();
}
"@

if (-not $ExePath) { $ExePath = Join-Path $PSScriptRoot '..\..\build\windows\x64\runner\Release\oj_float.exe' }
if (-not $OutPath) { $OutPath = Join-Path $PSScriptRoot '..\..\docs\images\demo.gif' }
$ExePath = (Resolve-Path $ExePath).Path
$outDir = Split-Path -Parent $OutPath
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

function Get-WindowTitle {
    param([IntPtr]$Handle)
    $sb = New-Object System.Text.StringBuilder 512
    [void][DemoWin32]::GetWindowText($Handle, $sb, $sb.Capacity)
    return $sb.ToString()
}

function Find-WindowByTitlePart {
    param([string]$Part)
    $script:findResult = [IntPtr]::Zero
    $callback = [DemoWin32+EnumWindowsProc] {
        param($hWnd, $lParam)
        $title = Get-WindowTitle $hWnd
        if ($title -like "*$Part*") {
            $script:findResult = $hWnd
            return $false
        }
        return $true
    }
    [void][DemoWin32]::EnumWindows($callback, [IntPtr]::Zero)
    return $script:findResult
}

function Minimize-OtherWindows {
    param([IntPtr[]]$Keep)
    $shell = [DemoWin32]::GetShellWindow()
    $callback = [DemoWin32+EnumWindowsProc] {
        param($hWnd, $lParam)
        if ($hWnd -eq [IntPtr]::Zero -or $hWnd -eq $shell) { return $true }
        if (-not [DemoWin32]::IsWindowVisible($hWnd)) { return $true }
        if ($Keep -notcontains $hWnd) {
            [void][DemoWin32]::ShowWindow($hWnd, 6)  # SW_MINIMIZE
        }
        return $true
    }
    [void][DemoWin32]::EnumWindows($callback, [IntPtr]::Zero)
}

function Read-ImportToken {
    param([string]$Dir)
    Add-Type -AssemblyName System.Security
    $dat = Join-Path $Dir 'flutter_secure_storage.dat'
    if (-not (Test-Path $dat)) { throw "Secure storage not found: $dat" }
    $encrypted = [System.IO.File]::ReadAllBytes($dat)
    $plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $encrypted, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $store = [System.Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json
    return $store.'oj_float_browser_import_token_v1'
}

function Invoke-DemoImport {
    param([string]$Token)
    $payload = [ordered]@{
        url        = 'https://codeforces.com/problemset/problem/9999/D'
        title      = 'D. Demo Problem — Prefix Sum'
        platform   = 'codeforces'
        externalId = '9999D'
        difficulty = '1300'
        tags       = @('prefix-sum', 'constructive')
    }
    $json = $payload | ConvertTo-Json -Depth 5
    # Write UTF-8 body bytes directly to the request stream (avoids
    # Invoke-RestMethod's code-page re-encoding on Windows PowerShell 5.1).
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $webRequest = [System.Net.HttpWebRequest]::Create('http://127.0.0.1:27121/v1/problems/import')
    $webRequest.Method = 'POST'
    $webRequest.ContentType = 'application/json; charset=utf-8'
    $webRequest.Headers['Authorization'] = "Bearer $Token"
    $webRequest.ContentLength = $bytes.Length
    $bodyStream = $webRequest.GetRequestStream()
    $bodyStream.Write($bytes, 0, $bytes.Length)
    $bodyStream.Close()
    $webResponse = $webRequest.GetResponse()
    $webResponse.Close()
}

function Write-WindowState {
    param([string]$Section)
    $state = [ordered]@{ version = 1; maximized = $false; section = $Section }
    $json = $state | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText(
        (Join-Path $DataDir 'window_state.json'), $json,
        (New-Object System.Text.UTF8Encoding($false)))
}

try {
    Stop-OjFloatProcess
    Write-WindowState -Section 'problems'

    # --- launch client ---
    $clientProc = Start-Process -FilePath $ExePath -PassThru
    $clientHwnd = Wait-ForWindow -Title 'OJ Float' -ClassName 'FLUTTER_RUNNER_WIN32_WINDOW' -TimeoutSeconds 40
    if ($clientHwnd -eq [IntPtr]::Zero) { throw 'OJ Float window did not appear.' }
    Start-Sleep -Seconds 6  # let init finish and the import server bind

    $token = Read-ImportToken -Dir $DataDir
    if (-not $token) { throw 'Import token is empty.' }

    # --- generate the working mock page with the real token ---
    $framesDir = Join-Path $env:TEMP ('oj-float-demo-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $framesDir -Force | Out-Null
    $template = [System.IO.File]::ReadAllText(
        (Join-Path $PSScriptRoot 'mock_problem.html'), [System.Text.Encoding]::UTF8)
    $mockPath = Join-Path $framesDir 'mock_problem.html'
    [System.IO.File]::WriteAllText($mockPath, $template.Replace('__TOKEN__', $token),
        (New-Object System.Text.UTF8Encoding($false)))

    # --- open the mock page in a browser (app-mode window when Edge is present) ---
    $edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
    if (Test-Path $edge) {
        $fileUrl = 'file:///' + ($mockPath -replace '\\', '/')
        Start-Process -FilePath $edge -ArgumentList "--app=$fileUrl"
    } else {
        Start-Process -FilePath $mockPath
    }
    $browserHwnd = Wait-ForWindow -Title 'OJ Float 演示题目 - Codeforces 9999D' -ClassName '' -TimeoutSeconds 30
    if ($browserHwnd -eq [IntPtr]::Zero) {
        $browserHwnd = Find-WindowByTitlePart '9999D'
    }
    Start-Sleep -Seconds 3  # let the page render

    # --- arrange the two windows side by side ---
    $clientRect = Get-WindowRect -Handle $clientHwnd
    $clientW = 1250; $clientH = 980
    Move-Window -Handle $clientHwnd -X 15 -Y 40 -Width $clientW -Height $clientH
    $browserW = 1240; $browserH = 980
    Move-Window -Handle $browserHwnd -X (15 + $clientW + 15) -Y 40 -Width $browserW -Height $browserH
    Start-Sleep -Milliseconds 800

    Minimize-OtherWindows -Keep @($clientHwnd, $browserHwnd)
    [ShowcaseWin32]::SetForegroundWindow($clientHwnd) | Out-Null
    Start-Sleep -Milliseconds 500

    # --- capture region is the union of both windows ---
    $clientRect = Get-WindowRect -Handle $clientHwnd
    $browserRect = Get-WindowRect -Handle $browserHwnd
    $left   = [Math]::Min($clientRect.Left, $browserRect.Left)
    $top    = [Math]::Min($clientRect.Top, $browserRect.Top)
    $right  = [Math]::Max($clientRect.Right, $browserRect.Right)
    $bottom = [Math]::Max($clientRect.Bottom, $browserRect.Bottom)
    $capW = $right - $left; $capH = $bottom - $top

    Write-Host "Recording demo: $capW x $capH, $Fps fps, ${DurationSeconds}s"
    $delayMs = [int](1000 / $Fps)
    $start = Get-Date
    $frame = 0
    $posted = $false
    while ((Get-Date) -lt $start.AddSeconds($DurationSeconds)) {
        $framePath = Join-Path $framesDir ('frame_{0:0000}.png' -f $frame)
        Capture-RegionPng -X $left -Y $top -Width $capW -Height $capH -OutPath $framePath
        $elapsed = ((Get-Date) - $start).TotalSeconds
        if (-not $posted -and $elapsed -ge 2.5) {
            Invoke-DemoImport -Token $token
            $posted = $true
            Write-Host '  POSTed import at ~2.5s'
        }
        $frame++
        Start-Sleep -Milliseconds $delayMs
    }
    Write-Host "Captured $frame frames."

    # --- assemble GIF ---
    & (Join-Path $PSScriptRoot 'frame_to_gif.ps1') `
        -FramesDir $framesDir -OutPath $OutPath -Fps $Fps -MaxWidth $MaxWidth
} finally {
    Stop-OjFloatProcess
}

Write-Host 'Demo recording complete.'
