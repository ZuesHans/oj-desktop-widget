#requires -Version 5.1
<#
.SYNOPSIS
  Script-driven browser-import for the OJ Float showcase demo.

.DESCRIPTION
  Posts a single fabricated problem to the running client's loopback import
  endpoint (127.0.0.1:27121). This is the "one-click save" used by the demo GIF;
  it performs the same HTTP call the browser extension would make, without
  needing a real browser extension or a real problem page.

  The pairing token is read from the client's DPAPI-protected secure storage
  file (flutter_secure_storage.dat), so this must run as the same Windows user
  that launched OJ Float.

.PARAMETER DataDir
  Application data directory. Defaults to "%APPDATA%\ZuesHans\OJ Float".

.PARAMETER ImportUrl
  Loopback import endpoint. Defaults to http://127.0.0.1:27121/v1/problems/import

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\showcase\import_problem.ps1
#>
[CmdletBinding()]
param(
    [string]$DataDir = (Join-Path $env:APPDATA 'ZuesHans\OJ Float'),
    [string]$ImportUrl = 'http://127.0.0.1:27121/v1/problems/import'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security

$datPath = Join-Path $DataDir 'flutter_secure_storage.dat'
if (-not (Test-Path $datPath)) {
    throw "Secure storage not found: $datPath (start OJ Float once first)."
}

$encrypted = [System.IO.File]::ReadAllBytes($datPath)
$plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
    $encrypted, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
$store = [System.Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json
$token = $store.'oj_float_browser_import_token_v1'
if (-not $token) {
    throw 'Browser import token not found in secure storage.'
}

$payload = [ordered]@{
    url        = 'https://codeforces.com/problemset/problem/9999/D'
    title      = 'D. Demo Problem — Prefix Sum'
    platform   = 'codeforces'
    externalId = '9999D'
    difficulty = '1300'
    tags       = @('prefix-sum', 'constructive')
}
$json = $payload | ConvertTo-Json -Depth 5

# Write the UTF-8 body bytes directly to the request stream. This avoids the
# code-page re-encoding that Invoke-RestMethod / string bodies suffer from on
# Windows PowerShell 5.1 (which would corrupt non-ASCII characters).
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
$request = [System.Net.HttpWebRequest]::Create($ImportUrl)
$request.Method = 'POST'
$request.ContentType = 'application/json; charset=utf-8'
$request.Headers['Authorization'] = "Bearer $token"
$request.ContentLength = $bytes.Length
$stream = $request.GetRequestStream()
$stream.Write($bytes, 0, $bytes.Length)
$stream.Close()

try {
    $response = $request.GetResponse()
    $reader = New-Object System.IO.StreamReader(
        $response.GetResponseStream(), [System.Text.Encoding]::UTF8)
    $responseBody = $reader.ReadToEnd()
    $reader.Close()
    $response.Close()
} catch [System.Net.WebException] {
    if ($_.Exception.Response) {
        $errorReader = New-Object System.IO.StreamReader(
            $_.Exception.Response.GetResponseStream(), [System.Text.Encoding]::UTF8)
        throw "Import failed: $($errorReader.ReadToEnd())"
    }
    throw "Import failed: $($_.Exception.Message)"
}
$responseBody | ConvertFrom-Json | ConvertTo-Json -Depth 5
