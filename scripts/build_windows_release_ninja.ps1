param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Test-Path $vswhere)) {
    throw "vswhere.exe was not found. Install Visual Studio with Desktop development with C++."
}

$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) {
    throw "Visual Studio C++ tools were not found."
}

$cmake = Join-Path $vsPath "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
$ninjaDir = Join-Path $vsPath "Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
$sdkToolDir = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.28000.0\x64"
$msvcRoot = Join-Path $vsPath "VC\Tools\MSVC"
$msvcToolDir = Join-Path $msvcRoot "14.51.36231\bin\Hostx64\x64"

foreach ($path in @($cmake, (Join-Path $ninjaDir "ninja.exe"), $vcvars, (Join-Path $msvcToolDir "cl.exe"), (Join-Path $sdkToolDir "rc.exe"), (Join-Path $sdkToolDir "mt.exe"))) {
    if (-not (Test-Path $path)) {
        throw "Required build tool not found: $path"
    }
}

$buildDir = Join-Path $repoRoot "build\windows\ninja"
$runnerDir = Join-Path $buildDir "runner"
$runnerExe = Join-Path $runnerDir "oj_float.exe"

if ($Clean -and (Test-Path $buildDir)) {
    Remove-Item -Recurse -Force $buildDir
}

$configure = @"
call "$vcvars" -vcvars_ver=14.51 && set PATH=$ninjaDir;$msvcToolDir;$sdkToolDir;%PATH% && "$cmake" -S windows -B build\windows\ninja -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=cl.exe -DCMAKE_CXX_COMPILER=cl.exe -DCMAKE_LINKER=link.exe -DCMAKE_RC_COMPILER="C:/Program Files (x86)/Windows Kits/10/bin/10.0.28000.0/x64/rc.exe" -DCMAKE_MT="C:/Program Files (x86)/Windows Kits/10/bin/10.0.28000.0/x64/mt.exe"
"@

$build = @"
call "$vcvars" -vcvars_ver=14.51 && set PATH=$ninjaDir;$msvcToolDir;$sdkToolDir;%PATH% && "$cmake" --build build\windows\ninja --config Release --target install
"@

function Invoke-CmdChecked {
    param([string]$Command)

    cmd.exe /d /s /c $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command"
    }
}

Get-Process oj_float -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $runnerExe } |
    Stop-Process -Force

Push-Location $repoRoot
try {
    Invoke-CmdChecked $configure
    Invoke-CmdChecked $build
} finally {
    Pop-Location
}

Write-Host "Windows release build complete:"
Write-Host $runnerDir
