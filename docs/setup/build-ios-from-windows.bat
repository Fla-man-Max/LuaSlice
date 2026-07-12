@echo off
setlocal EnableExtensions EnableDelayedExpansion
title LuaSlice iOS Builder

if /i "%~1"=="--help" (
  echo Usage: build-ios-from-windows.bat [owner/repository] [branch]
  echo Default: Fla-man-Max/LuaSlice main
  exit /b 0
)

set "REPO=%~1"
if not defined REPO set "REPO=Fla-man-Max/LuaSlice"

set "BRANCH=%~2"
if not defined BRANCH set "BRANCH=main"

set "WORKFLOW=build-ios.yml"
set "GH=gh"

where gh >nul 2>nul
if errorlevel 1 (
  echo GitHub CLI is not installed. Installing it now...
  where winget >nul 2>nul
  if errorlevel 1 (
    echo GitHub CLI is required. Install it from https://cli.github.com/
    pause
    exit /b 1
  )

  winget install --id GitHub.cli --exact --source winget --accept-package-agreements --accept-source-agreements
  if errorlevel 1 (
    echo GitHub CLI installation failed.
    pause
    exit /b 1
  )

  set "GH=C:\Program Files\GitHub CLI\gh.exe"
  if not exist "!GH!" (
    echo GitHub CLI was installed, but this window cannot find it yet.
    echo Close this window and run the file again.
    pause
    exit /b 1
  )
)

call "%GH%" auth status --hostname github.com >nul 2>nul
if errorlevel 1 (
  echo Sign in to GitHub in the browser window.
  call "%GH%" auth login --hostname github.com --web
  if errorlevel 1 exit /b 1
)

echo.
echo Repository: %REPO%
echo Branch: %BRANCH%
echo.

set "PREVIOUS_RUN="
for /f "delims=" %%R in ('call "%GH%" run list --repo "%REPO%" --workflow "%WORKFLOW%" --branch "%BRANCH%" --event workflow_dispatch --limit 1 --json databaseId --jq ".[0].databaseId" 2^>nul') do set "PREVIOUS_RUN=%%R"

echo Starting the iOS Simulator and physical iPhone builds on a macOS runner...
call "%GH%" workflow run "%WORKFLOW%" --repo "%REPO%" --ref "%BRANCH%"
if errorlevel 1 (
  echo.
  echo The workflow could not start. Make sure build-ios.yml is pushed to GitHub.
  pause
  exit /b 1
)

set /a ATTEMPTS=0
:WAIT_FOR_RUN
timeout /t 3 /nobreak >nul
set "RUN_ID="
for /f "delims=" %%R in ('call "%GH%" run list --repo "%REPO%" --workflow "%WORKFLOW%" --branch "%BRANCH%" --event workflow_dispatch --limit 1 --json databaseId --jq ".[0].databaseId"') do set "RUN_ID=%%R"

set /a ATTEMPTS+=1
if !ATTEMPTS! GEQ 40 (
  echo Timed out while waiting for GitHub to create the build.
  pause
  exit /b 1
)
if not defined RUN_ID goto WAIT_FOR_RUN
if defined PREVIOUS_RUN if "!RUN_ID!"=="!PREVIOUS_RUN!" goto WAIT_FOR_RUN

echo Build run: !RUN_ID!
call "%GH%" run watch "!RUN_ID!" --repo "%REPO%" --exit-status
if errorlevel 1 (
  echo.
  echo The iOS build failed. Opening the failed log...
  call "%GH%" run view "!RUN_ID!" --repo "%REPO%" --log-failed
  pause
  exit /b 1
)

if defined LUASLICE_IOS_OUTPUT (
  set "OUTPUT=!LUASLICE_IOS_OUTPUT!\LuaSlice iOS !RUN_ID!"
) else (
  for /f "delims=" %%D in ('powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"') do set "DESKTOP=%%D"
  set "OUTPUT=!DESKTOP!\LuaSlice iOS !RUN_ID!"
)
mkdir "!OUTPUT!" >nul 2>nul

echo Downloading the iOS build...
call "%GH%" run download "!RUN_ID!" --repo "%REPO%" --name "LuaSlice-iOS-Simulator" --dir "!OUTPUT!"
if errorlevel 1 (
  echo The build passed, but its artifact could not be downloaded.
  pause
  exit /b 1
)
call "%GH%" run download "!RUN_ID!" --repo "%REPO%" --name "LuaSlice-iOS-Unsigned-IPA" --dir "!OUTPUT!"
if errorlevel 1 (
  echo The Simulator build downloaded, but the physical iPhone IPA did not.
  pause
  exit /b 1
)

echo.
echo iOS builds downloaded to:
echo !OUTPUT!
if not defined LUASLICE_IOS_NO_OPEN start "" "!OUTPUT!"
if defined LUASLICE_IOS_NO_PAUSE exit /b 0
pause
