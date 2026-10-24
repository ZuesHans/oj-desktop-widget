param(
  [ValidateSet('Debug', 'Release')]
  [string]$Configuration = 'Release',
  [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$companionRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $companionRoot
$buildDirectory = Join-Path $repositoryRoot 'build\native_companion'
$sqliteCandidates = @(
  (Join-Path $repositoryRoot 'build\native_assets\windows\sqlite3.dll'),
  (Join-Path $repositoryRoot 'build\windows\x64\runner\Release\sqlite3.dll')
)
$sqliteDll = $sqliteCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $sqliteDll) {
  $sqliteDll = Get-ChildItem (Join-Path $repositoryRoot '.dart_tool\hooks_runner') -Filter sqlite3.dll -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
}
if (-not $sqliteDll) {
  throw 'sqlite3.dll is missing. Run flutter test or flutter build windows --release first.'
}

$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmake) {
  $cmakePath = Get-ChildItem 'C:\Program Files\Microsoft Visual Studio' -Filter cmake.exe -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
  if (-not $cmakePath) {
    throw 'CMake was not found. Install the Visual Studio C++ desktop workload.'
  }
  $cmakeExecutable = $cmakePath
} else {
  $cmakeExecutable = $cmake.Source
}

& $cmakeExecutable -S $companionRoot -B $buildDirectory "-DOJ_SQLITE_DLL=$($sqliteDll.Replace('\', '/'))"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $cmakeExecutable --build $buildDirectory --config $Configuration
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not $SkipTests) {
  $ctestExecutable = Join-Path (Split-Path -Parent $cmakeExecutable) 'ctest.exe'
  & $ctestExecutable --test-dir $buildDirectory -C $Configuration --output-on-failure
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$executable = Join-Path $buildDirectory "$Configuration\oj_problem_companion.exe"
Write-Host "Native companion built: $executable"
