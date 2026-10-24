$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$toolsDirectory = Join-Path $repositoryRoot 'build\tools'
$compilerDirectory = Join-Path $toolsDirectory 'inno'
$compilerPath = Join-Path $compilerDirectory 'ISCC.exe'
if (Test-Path -LiteralPath $compilerPath) { Write-Output $compilerPath; return }
New-Item -ItemType Directory -Force -Path $toolsDirectory | Out-Null
$bootstrapPath = Join-Path $toolsDirectory 'innosetup-7.1.0-x64.exe'
Invoke-WebRequest -Uri 'https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe' -OutFile $bootstrapPath
$expected = '0362a383ed217d4c4239b5933866dd96d3eb2102737da92f80f6057a4b40df2f'
if ((Get-FileHash -LiteralPath $bootstrapPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
  throw 'Inno Setup download checksum mismatch.'
}
if ((Get-AuthenticodeSignature -LiteralPath $bootstrapPath).Status -ne 'Valid') {
  throw 'Inno Setup bootstrap signature is invalid.'
}
$process = Start-Process -FilePath $bootstrapPath -ArgumentList @(
  '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/CURRENTUSER','/NOICONS',
  ('/DIR="' + $compilerDirectory + '"'),'/TASKS='
) -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Inno Setup compiler installation failed: $($process.ExitCode)" }
Write-Output $compilerPath
