@echo off
setlocal

set "ANDROID_SDK=%LOCALAPPDATA%\Android\Sdk"
set "ANDROID_NDK=%ANDROID_SDK%\ndk\29.0.13113456"

echo LuaSlice Android setup
echo.
echo Expected:
echo - Android command-line tools installed
echo - JDK 17 installed
echo - sdkmanager available in PATH, or run this from cmdline-tools\latest\bin
echo.

where sdkmanager >nul 2>nul
if errorlevel 1 (
  echo ERROR: sdkmanager was not found in PATH.
  echo Install Android command-line tools first, then retry.
  pause
  exit /b 1
)

where java >nul 2>nul
if errorlevel 1 (
  echo ERROR: Java was not found in PATH.
  echo Install JDK 17 first, then retry.
  pause
  exit /b 1
)

echo Installing Android SDK packages...
sdkmanager --sdk_root="%ANDROID_SDK%" "build-tools;35.0.0" "platforms;android-29" "platforms;android-35" "ndk;29.0.13113456"
if errorlevel 1 goto failed

echo Configuring Lime...
haxelib run lime config ANDROID_SDK "%ANDROID_SDK%"
haxelib run lime config ANDROID_NDK_ROOT "%ANDROID_NDK%"
haxelib run lime config ANDROID_SETUP true
if errorlevel 1 goto failed

echo.
echo Done. Run: lime build android
pause
exit /b 0

:failed
echo.
echo Android setup failed. Check the error above.
pause
exit /b 1
