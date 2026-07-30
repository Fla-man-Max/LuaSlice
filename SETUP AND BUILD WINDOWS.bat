@echo off
setlocal
cd /d "%~dp0"
title LuaSlice setup

echo.
echo LuaSlice setup + Windows build
echo.

where winget >nul 2>nul
if errorlevel 1 (
  echo winget is missing. Install App Installer from the Microsoft Store.
  goto :fail
)

echo [1/5] Git and Haxe
call :install Git.Git
if errorlevel 1 goto :fail

call :install HaxeFoundation.Haxe
if errorlevel 1 goto :fail

echo.
echo [2/5] Visual Studio C++ tools
winget install --source winget --accept-source-agreements --accept-package-agreements --exact --id Microsoft.VisualStudio.2022.BuildTools --force --override "--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
if errorlevel 1 goto :fail

set "PATH=C:\Program Files\Git\cmd;C:\HaxeToolkit\haxe;%PATH%"

where git >nul 2>nul
if errorlevel 1 (
  echo Git is not available yet. Close this window and run the file again.
  goto :fail
)

where haxe >nul 2>nul
if errorlevel 1 (
  echo Haxe is not available yet. Close this window and run the file again.
  goto :fail
)

echo.
echo [3/5] HMM
haxelib --global install hmm
if errorlevel 1 (
  haxelib --global git hmm https://github.com/FunkinCrew/hmm.git
  if errorlevel 1 goto :fail
)

haxelib --global run hmm setup
if errorlevel 1 goto :fail

if exist ".git" (
  git submodule update --init --recursive
  if errorlevel 1 goto :fail
)

set "TEMP_HMM=0"
if not exist "hmm.json" (
  if not exist "other\hmm.json" (
    echo other\hmm.json is missing.
    goto :fail
  )
  copy /y "other\hmm.json" "hmm.json" >nul
  set "TEMP_HMM=1"
)

echo.
echo [4/5] Libraries and Lime
haxelib --global run hmm install
set "HMM_RESULT=%ERRORLEVEL%"
if "%TEMP_HMM%"=="1" del /q "hmm.json"
if not "%HMM_RESULT%"=="0" goto :fail

haxelib run lime setup
if errorlevel 1 goto :fail

echo.
echo [5/5] lime test windows
haxelib run lime test windows
if errorlevel 1 goto :fail

echo.
echo Done.
pause
exit /b 0

:install
winget install --source winget --accept-source-agreements --accept-package-agreements --exact --id %~1
exit /b %ERRORLEVEL%

:fail
if "%TEMP_HMM%"=="1" if exist "hmm.json" del /q "hmm.json"
echo.
echo Setup or build failed. Check the error above.
pause
exit /b 1
