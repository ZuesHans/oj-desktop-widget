@echo off
setlocal

if exist "%USERPROFILE%\tools\Git\cmd\git.exe" (
  "%USERPROFILE%\tools\Git\cmd\git.exe" %*
  exit /b %ERRORLEVEL%
)

if exist "%ProgramFiles%\Git\cmd\git.exe" (
  "%ProgramFiles%\Git\cmd\git.exe" %*
  exit /b %ERRORLEVEL%
)

if exist "%ProgramFiles(x86)%\Git\cmd\git.exe" (
  "%ProgramFiles(x86)%\Git\cmd\git.exe" %*
  exit /b %ERRORLEVEL%
)

git.exe %*
