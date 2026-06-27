# Compiling LuaSlice for Mobile

Build desktop first:

```bat
lime test windows
```

## Android

Use JDK 17 and NDK `29.0.13113456`. Newer NDK versions can break Lime/OpenFL builds.

Install SDK packages:

```bat
sdkmanager --install "build-tools;35.0.0" "platforms;android-29" "platforms;android-35" "ndk;29.0.13113456"
```

Run Lime setup:

```bat
lime setup android
```

Use these paths when asked:

- Android SDK: your Android SDK folder
- Android NDK: `your Android SDK folder\ndk\29.0.13113456`
- JDK: your JDK 17 folder

Build only:

```bat
lime build android
```

Build and install to a connected phone or emulator:

```bat
lime test android
```

The APK is usually here:

```text
export/release/android/bin/app/build/outputs/apk/
```

If LuaSlice is installed next to another FNF build, make sure `PACKAGE_NAME` in `project.hxp` is unique, for example `me.luaslice`.

## Android logs

LuaSlice keeps Android build/run logs in:

```text
BuildLogs/android/
```

Readable latest log:

```text
BuildLogs/android/android-readable-latest.log
```

Raw latest log:

```text
BuildLogs/android/android-raw-latest.log
```

To collect a fresh readable run log:

```bat
powershell -ExecutionPolicy Bypass -File tools\android-readable-log.ps1 -Launch -Seconds 35
```

## Android emulator

1. Open Android Studio.
2. Open Device Manager.
3. Create and start a device.
4. Run:

```bat
lime test android
```

If Lime does not pick the right target:

```bat
adb devices
adb install path\to\LuaSlice.apk
```

## iOS

iOS needs macOS and Xcode.

Real device:

```sh
lime test ios -xcode
```

Simulator:

```sh
lime test ios -simulator
```

If signing fails:

- Change `IOS_TEAM_ID` in `project.hxp`.
- Change `PACKAGE_NAME` away from the official FNF package name.
- Add your Apple ID in Xcode settings.
