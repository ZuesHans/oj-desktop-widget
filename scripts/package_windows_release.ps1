param(
  [switch]$SkipBuild,
  [switch]$SkipInstaller,
  [string]$Flutter = 'flutter',
  [string]$InnoCompiler = '',
  [string]$VCRedistDirectory = '',
  [string]$InstallerAppId = 'io.github.zueshans.ojfloat'
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
$fullVersion = $versionLine.Matches[0].Groups[1].Value
if ($fullVersion -notmatch '^(\d+\.\d+\.\d+)\+(\d+)$') {
  throw 'Stable packaging requires a numeric version+build in pubspec.yaml.'
}
$version = $Matches[1]
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
  Push-Location -LiteralPath $repositoryRoot
  try {
    & $Flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }
    & (Join-Path $repositoryRoot 'native_companion\build.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Native companion build failed.' }
  } finally {
    Pop-Location
  }
}
& (Join-Path $repositoryRoot 'browser_extension\tampermonkey\build.ps1') -Check
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$runnerPath = Join-Path $repositoryRoot 'build\windows\x64\runner\Release'
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
foreach ($exe in @((Join-Path $runnerPath 'oj_float.exe'), (Join-Path $companionPath 'oj_problem_companion.exe'))) {
  $builtVersion = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
  if ($builtVersion -ne $fullVersion) {
    throw "Version mismatch for ${exe}: $builtVersion; expected $fullVersion. Rebuild both programs."
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
if (-not $VCRedistDirectory) {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  $visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (-not $visualStudio) { throw 'Visual C++ redistributable directory not found. Pass -VCRedistDirectory.' }
  $redistRoot = Join-Path $visualStudio 'VC\Redist\MSVC'
  $redistVersions = Get-ChildItem -LiteralPath $redistRoot -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+' } |
    Sort-Object { [version]($_.Name -replace '[^0-9.].*$', '') } -Descending
  foreach ($redistVersion in $redistVersions) {
    $candidate = Get-ChildItem -LiteralPath (Join-Path $redistVersion.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { $VCRedistDirectory = $candidate.FullName; break }
  }
}
foreach ($runtime in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
  if (-not (Test-Path -LiteralPath (Join-Path $VCRedistDirectory $runtime))) {
    throw "Visual C++ runtime is missing: $runtime"
  }
}
Get-ChildItem -LiteralPath $VCRedistDirectory -Filter '*.dll' -File |
  ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $stagePath }
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'browser_extension\tampermonkey\oj-float-importer.user.js') -Destination $stagePath
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'packaging\windows\README.md') -Destination $stagePath
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'LICENSE') -Destination $stagePath
$extensionPath = Join-Path $stagePath 'browser_extension'
New-Item -ItemType Directory -Path $extensionPath | Out-Null
foreach ($name in @('manifest.json','popup.html','popup.js','popup.css','extractor.js','README.md')) {
  Copy-Item -LiteralPath (Join-Path $repositoryRoot "browser_extension\$name") -Destination $extensionPath
}

Compress-Archive -Path (Join-Path $stagePath '*') -DestinationPath $zipPath -CompressionLevel Optimal
$artifacts = @($zipPath)

if (-not $SkipInstaller) {
  if (-not $InnoCompiler) {
    $compilerCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $candidates = @(
      $(if ($compilerCommand) { $compilerCommand.Source }),
      (Join-Path $repositoryRoot 'build\tools\inno\ISCC.exe'),
      "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
      "$env:LOCALAPPDATA\Programs\Inno Setup 7\ISCC.exe"
    )
    $InnoCompiler = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
  }
  if (-not $InnoCompiler) { throw 'Install Inno Setup or pass -InnoCompiler with the ISCC.exe path.' }
  & $InnoCompiler "/DAppVersion=$version" "/DStageDir=$stagePath" "/DOutputDir=$distRoot" "/DAppIdValue=$InstallerAppId" (Join-Path $repositoryRoot 'packaging\windows\oj-float.iss')
  if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
  $artifacts += Join-Path $distRoot "$packageName-setup.exe"
}
$checksumLines = foreach ($artifact in $artifacts) {
  $hash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
  "$hash  $([System.IO.Path]::GetFileName($artifact))"
}
$checksumLines | Set-Content -LiteralPath (Join-Path $distRoot "OJ-Float-v$version-SHA256SUMS.txt") -Encoding ascii
Write-Host "Release artifacts: $distRoot"
$checksumLines | ForEach-Object { Write-Host $_ }
