param(
  [string]$InnoCompiler = '',
  [string]$StageDirectory = '',
  [string]$Version = '0.2.0'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $InnoCompiler) { $InnoCompiler = Join-Path $repositoryRoot 'build\tools\inno\ISCC.exe' }
if (-not $StageDirectory) { $StageDirectory = Join-Path $repositoryRoot "dist\OJ-Float-v$Version-windows-x64" }
$smokeId = "io.github.zueshans.ojfloat.smoke.$PID"
$smokeRoot = Join-Path $repositoryRoot "build\installer-smoke-$PID"
$installPath = Join-Path $smokeRoot 'installed'
$smokeData = Join-Path $smokeRoot 'data'
$groupName = "OJ Float smoke $PID"
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\${smokeId}_is1"
$dataRoot = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'ZuesHans\OJ Float'
$dataAlreadyExisted = Test-Path -LiteralPath $dataRoot
$sentinel = Join-Path $dataRoot "installer-smoke-$PID.txt"

function Run-Checked([string]$Executable, [string[]]$Arguments) {
  $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -WindowStyle Hidden -PassThru
  if (-not $process.WaitForExit(45000)) { throw "Process did not exit: $Executable (PID $($process.Id))" }
  if ($process.ExitCode -ne 0) { throw "Process failed: $Executable ($($process.ExitCode))" }
}

function Run-Migration([string]$Directory, [int]$ExpectedExit) {
  $process = Start-Process -FilePath (Join-Path $installPath 'oj_float.exe') -ArgumentList @(
    '--migrate-problem-database-and-exit','--migration-directory',('"' + $Directory + '"')
  ) -WindowStyle Hidden -PassThru
  if (-not $process.WaitForExit(45000)) { throw 'Installed migration did not finish.' }
  if ($process.ExitCode -ne $ExpectedExit) {
    throw "Migration returned $($process.ExitCode); expected $ExpectedExit."
  }
}

New-Item -ItemType Directory -Path $smokeRoot | Out-Null
New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
Set-Content -LiteralPath $sentinel -Value 'Uninstall must retain application data.' -Encoding utf8
$beforeData = @{}
Get-ChildItem -LiteralPath $dataRoot -File -Recurse | ForEach-Object {
  $beforeData[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
}
$installer = Join-Path $smokeRoot 'setup-smoke.exe'
$uninstaller = Join-Path $installPath 'unins000.exe'
try {
  # The old product was zip-only. Use the same AppId with an earlier installer
  # version to exercise Inno's actual version/registry/shortcut upgrade path.
  $previousInstallerVersion = '0.1.3'
  & $InnoCompiler "/DAppVersion=$previousInstallerVersion" "/DStageDir=$StageDirectory" "/DOutputDir=$smokeRoot" "/DAppIdValue=$smokeId" "/DAppGroupName=$groupName" '/DOutputName=setup-smoke' (Join-Path $repositoryRoot 'packaging\windows\oj-float.iss')
  if ($LASTEXITCODE -ne 0) { throw 'Smoke installer compilation failed.' }
  $arguments = @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',('/DIR="' + $installPath + '"'),('/GROUP="' + $groupName + '"'),'/TASKS=')
  Run-Checked $installer ($arguments + ('/LOG="' + (Join-Path $smokeRoot 'install.log') + '"'))
  foreach ($file in @('oj_float.exe','oj_problem_companion.exe','sqlite3.dll','msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll','data\app.so','unins000.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $installPath $file))) { throw "Install is missing $file" }
  }
  $entry = Get-ItemProperty -LiteralPath $uninstallKey
  if ($entry.DisplayVersion -ne $previousInstallerVersion) { throw 'Uninstall registration has the wrong previous version.' }
  $programs = [Environment]::GetFolderPath('Programs')
  foreach ($name in @('OJ Float.lnk','OJ Problem Companion.lnk','Uninstall OJ Float.lnk')) {
    if (-not (Test-Path -LiteralPath (Join-Path $programs "$groupName\$name"))) { throw "Shortcut missing: $name" }
  }
  Run-Migration $smokeData 0
  if (-not (Test-Path -LiteralPath (Join-Path $smokeData 'problem_book.sqlite3'))) { throw 'Installed client did not initialize its isolated database.' }
  Write-Host 'Clean per-user install, shortcuts, uninstall entry, and installed Flutter migration passed.'

  $failedData = Join-Path $smokeRoot 'failed-data'
  New-Item -ItemType Directory -Path $failedData | Out-Null
  $legacyFile = Join-Path $failedData 'problems_v1.json'
  Set-Content -LiteralPath $legacyFile -Value '{broken-legacy-json' -Encoding utf8
  $originalHash = (Get-FileHash -LiteralPath $legacyFile).Hash
  Run-Migration $failedData 1
  if ((Get-FileHash -LiteralPath $legacyFile).Hash -ne $originalHash) { throw 'Failed migration modified the original legacy file.' }
  Set-Content -LiteralPath $legacyFile -Value '[]' -Encoding utf8
  Run-Migration $failedData 0
  Write-Host 'Installed migration rejects damaged JSON with exit 1, preserves it, and succeeds after repair.'

  # Exercise replacement of an installed payload and preservation of local data.
  Set-Content -LiteralPath (Join-Path $installPath 'README.md') -Value 'Previous installed payload'
  & $InnoCompiler "/DAppVersion=$Version" "/DStageDir=$StageDirectory" "/DOutputDir=$smokeRoot" "/DAppIdValue=$smokeId" "/DAppGroupName=$groupName" '/DOutputName=setup-smoke' (Join-Path $repositoryRoot 'packaging\windows\oj-float.iss')
  if ($LASTEXITCODE -ne 0) { throw 'Upgrade installer compilation failed.' }
  Run-Checked $installer ($arguments + ('/LOG="' + (Join-Path $smokeRoot 'upgrade.log') + '"'))
  if ((Get-ItemProperty -LiteralPath $uninstallKey).DisplayVersion -ne $Version) { throw 'Upgrade did not update the registered version.' }
  if ((Get-FileHash -LiteralPath (Join-Path $installPath 'README.md')).Hash -ne
      (Get-FileHash -LiteralPath (Join-Path $StageDirectory 'README.md')).Hash) {
    throw 'Upgrade did not replace the installed payload.'
  }
  if (-not (Test-Path -LiteralPath $sentinel)) { throw 'Upgrade removed user data.' }
  Write-Host 'In-place reinstall/upgrade replaced the payload and retained user data.'

  Run-Checked $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="' + (Join-Path $smokeRoot 'uninstall.log') + '"'))
  if (Test-Path -LiteralPath $uninstallKey) { throw 'Uninstall registration remains.' }
  foreach ($file in @('oj_float.exe','oj_problem_companion.exe','data\app.so')) {
    if (Test-Path -LiteralPath (Join-Path $installPath $file)) { throw "Uninstall left $file" }
  }
  if (Test-Path -LiteralPath (Join-Path $programs $groupName)) { throw 'Start menu shortcuts remain.' }
  foreach ($entry in $beforeData.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Key) -or
        (Get-FileHash -LiteralPath $entry.Key -Algorithm SHA256).Hash -ne $entry.Value) {
      throw 'Uninstall changed application data.'
    }
  }
  Write-Host "Uninstall removed the programs and shortcuts; all $($beforeData.Count) original data files retained byte-for-byte."
  Write-Host "Smoke logs: $smokeRoot"
} finally {
  if (Test-Path -LiteralPath $uninstallKey) {
    if (Test-Path -LiteralPath $uninstaller) { Run-Checked $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') }
  }
  if (Test-Path -LiteralPath $sentinel) { Remove-Item -LiteralPath $sentinel }
  if (-not $dataAlreadyExisted -and (Test-Path -LiteralPath $dataRoot) -and
      @(Get-ChildItem -LiteralPath $dataRoot -Force).Count -eq 0) {
    Remove-Item -LiteralPath $dataRoot
  }
}
