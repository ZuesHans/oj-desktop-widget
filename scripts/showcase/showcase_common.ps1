#requires -Version 5.1
<#
.SYNOPSIS
  Shared Win32 window/screen capture helpers for the OJ Float showcase scripts.
  Dot-source this file from capture_screenshots.ps1 / record_demo.ps1.
#>

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ShowcaseWin32 {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string className, string windowName);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, ref RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter,
        int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@

# Make coordinate math physical-pixel based so capture is correct under any DPI.
[ShowcaseWin32]::SetProcessDPIAware() | Out-Null

# HWND_BOTTOM etc. are not required; we use SWP_NOZORDER (0x0004) + SWP_NOACTIVATE (0x0010).
$ShowcaseSwpFlags = 0x0004 -bor 0x0010  # SWP_NOZORDER | SWP_NOACTIVATE

function Get-WindowRect {
    param([IntPtr]$Handle)
    $rect = New-Object 'ShowcaseWin32+RECT'
    if (-not [ShowcaseWin32]::GetWindowRect($Handle, [ref]$rect)) {
        throw "GetWindowRect failed for handle $Handle"
    }
    return $rect
}

function Wait-ForWindow {
    param(
        [string]$Title,
        [string]$ClassName,
        [int]$TimeoutSeconds = 20
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        # FindWindow treats an empty-string class as a literal (non-matching)
        # class name; pass $null to match any class.
        $classArg = if ([string]::IsNullOrEmpty($ClassName)) { $null } else { $ClassName }
        $hwnd = [ShowcaseWin32]::FindWindow($classArg, $Title)
        if ($hwnd -ne [IntPtr]::Zero) {
            return $hwnd
        }
        Start-Sleep -Milliseconds 300
    }
    return [IntPtr]::Zero
}

function Move-Window {
    param(
        [IntPtr]$Handle,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )
    [ShowcaseWin32]::SetWindowPos($Handle, [IntPtr]::Zero, $X, $Y, $Width, $Height, $ShowcaseSwpFlags) | Out-Null
}

function Capture-RegionPng {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [string]$OutPath
    )
    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $size = New-Object System.Drawing.Size($Width, $Height)
    $graphics.CopyFromScreen($X, $Y, 0, 0, $size)
    $graphics.Dispose()
    $bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

function Stop-OjFloatProcess {
    Get-Process oj_float -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

function Click-At {
    param([int]$X, [int]$Y)
    [ShowcaseWin32]::SetCursorPos($X, $Y) | Out-Null
    Start-Sleep -Milliseconds 90
    [ShowcaseWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero) | Out-Null  # LEFTDOWN
    Start-Sleep -Milliseconds 50
    [ShowcaseWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero) | Out-Null  # LEFTUP
    Start-Sleep -Milliseconds 200
}
