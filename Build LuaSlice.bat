@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
if /i "%~1"=="--help" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Build.ps1" -Mode help
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Build.ps1" -Mode build %*
exit /b %errorlevel%
