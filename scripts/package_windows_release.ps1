param(
  [switch]$SkipBuild,
  [switch]$SkipDesktopShortcuts
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath(
  (Join-Path $PSScriptRoot '..')
)
$pubspecPath = Join-Path $repositoryRoot 'pubspec.yaml'
$versionLine = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(\S+)\s*$' |
  Select-Object -First 1
if (-not $versionLine) {
  throw 'Unable to read the application version from pubspec.yaml.'
}
$version = $versionLine.Matches[0].Groups[1].Value
$packageName = "OJ-Float-v$version-windows-x64"
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot 'dist'))
$stagePath = [System.IO.Path]::GetFullPath((Join-Path $distRoot $packageName))
$zipPath = [System.IO.Path]::GetFullPath((Join-Path $distRoot "$packageName.zip"))
$expectedPrefix = $distRoot.TrimEnd('\') + '\'
if (-not $stagePath.StartsWith($expectedPrefix,
    [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe staging path: $stagePath"
}

if (-not $SkipBuild) {
  & (Join-Path $PSScriptRoot 'build_windows_release_ninja.ps1')
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & (Join-Path $repositoryRoot 'native_companion\build.ps1')
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& (Join-Path $repositoryRoot 'browser_extension\tampermonkey\build.ps1') -Check
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$runnerPath = Join-Path $repositoryRoot 'build\windows\ninja\runner'
$companionPath = Join-Path $repositoryRoot 'build\native_companion\Release'
$requiredSources = @(
  (Join-Path $runnerPath 'oj_float.exe'),
  (Join-Path $runnerPath 'flutter_windows.dll'),
  (Join-Path $runnerPath 'data\app.so'),
  (Join-Path $runnerPath 'data\icudtl.dat'),
  (Join-Path $companionPath 'oj_problem_companion.exe'),
  (Join-Path $companionPath 'sqlite3.dll'),
  (Join-Path $repositoryRoot 'browser_extension\tampermonkey\oj-float-importer.user.js')
)
foreach ($source in $requiredSources) {
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Required release file is missing: $source"
  }
}

New-Item -ItemType Directory -Force $distRoot | Out-Null
if (Test-Path -LiteralPath $stagePath) {
  Remove-Item -LiteralPath $stagePath -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}
New-Item -ItemType Directory -Path $stagePath | Out-Null

Get-ChildItem -LiteralPath $runnerPath -File |
  Where-Object { $_.Extension -in '.exe', '.dll' -or $_.Name -eq 'native_assets.json' } |
  ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $stagePath }
Copy-Item -LiteralPath (Join-Path $runnerPath 'data') -Destination $stagePath -Recurse
Copy-Item -LiteralPath (Join-Path $companionPath 'oj_problem_companion.exe') -Destination $stagePath
Copy-Item -LiteralPath (Join-Path $companionPath 'sqlite3.dll') -Destination $stagePath
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'browser_extension\tampermonkey\oj-float-importer.user.js') -Destination $stagePath
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'packaging\windows\README.md') -Destination $stagePath
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'LICENSE') -Destination $stagePath

Compress-Archive -Path (Join-Path $stagePath '*') -DestinationPath $zipPath -CompressionLevel Optimal
$hash = Get-FileHash -LiteralPath $zipPath -Algorithm SHA256

if (-not $SkipDesktopShortcuts) {
  $desktopPath = [Environment]::GetFolderPath('Desktop')
  $shell = New-Object -ComObject WScript.Shell

  $clientShortcut = $shell.CreateShortcut(
    (Join-Path $desktopPath 'oj_float.exe.lnk')
  )
  $clientShortcut.TargetPath = Join-Path $stagePath 'oj_float.exe'
  $clientShortcut.WorkingDirectory = $stagePath
  $clientShortcut.IconLocation = "$(Join-Path $stagePath 'oj_float.exe'),0"
  $clientShortcut.Description = "OJ Float $version"
  $clientShortcut.Save()

  $companionShortcut = $shell.CreateShortcut(
    (Join-Path $desktopPath 'OJ 题库小程序.lnk')
  )
  $companionShortcut.TargetPath = Join-Path $stagePath 'oj_problem_companion.exe'
  $companionShortcut.WorkingDirectory = $stagePath
  $companionShortcut.IconLocation = "$(Join-Path $stagePath 'oj_problem_companion.exe'),0"
  $companionShortcut.Description = "OJ Float C++ 题库小程序 $version"
  $companionShortcut.Save()

  Write-Host "Desktop shortcuts updated: $desktopPath"
}

Write-Host "Windows package created: $zipPath"
Write-Host "SHA256: $($hash.Hash)"
