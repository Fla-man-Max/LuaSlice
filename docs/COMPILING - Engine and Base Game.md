# Compiling LuaSlice and the Base Game

This guide is for LuaSlice and the original FNF V-Slice source layout. Run commands from the repo root, where `project.hxp` and `hmm.json` are.

## 1. Install libraries

Do not download the repo with GitHub's Download ZIP button. Clone it with Git so submodules and source paths stay correct.

```bat
git clone https://github.com/FunkinCrew/funkin.git
cd funkin
git submodule update --init --recursive
haxelib --global install hmm
haxelib --global run hmm setup
hmm install
haxelib run lime setup
```

If `hmm` or `haxelib` has trouble with Funkin's pinned libraries, use Funkin's patched versions:

```bat
haxelib --global git haxelib https://github.com/FunkinCrew/haxelib.git
haxelib --global git hmm https://github.com/FunkinCrew/hmm.git
hmm install
```

## 2. Desktop sanity check

Build desktop before mobile. If desktop is broken, Android/iOS will usually be broken too.

```bat
lime test windows
```

Other desktop targets:

```sh
lime test linux
lime test mac
```

Windows needs Visual Studio Build Tools with:

- MSVC v143 VS 2022 C++ x64/x86 build tools
- Windows 10 or Windows 11 SDK

Linux needs VLC development packages:

```sh
sudo apt install libvlc-dev libvlccore-dev libvlccore9
```

macOS needs Lime's mac setup:

```sh
lime setup mac
```

## 3. Common build commands

```bat
lime build windows
lime test windows
lime build android
lime test android
```

If native builds act weird after changing libraries:

```bat
lime rebuild windows
lime rebuild windows -debug
lime rebuild android
lime rebuild android -debug
```

## 4. Useful flags

- `-debug` builds with debug tools and less optimization.
- `-DFEATURE_POLYMOD_MODS` forces mod support on.
- `-DNO_FEATURE_POLYMOD_MODS` forces mod support off.
- `-DREDIRECT_ASSETS_FOLDER` loads assets from the repo assets folder for faster testing.
- `-DNO_REDIRECT_ASSETS_FOLDER` disables asset redirection.
- `-DFEATURE_DISCORD_RPC` enables Discord RPC.
- `-DNO_FEATURE_DISCORD_RPC` disables Discord RPC.
- `-DFEATURE_VIDEO_PLAYBACK` enables video playback.
- `-DNO_FEATURE_VIDEO_PLAYBACK` disables video playback.
- `-DFEATURE_CHART_EDITOR` enables the chart editor.
- `-DNO_FEATURE_CHART_EDITOR` disables the chart editor.
- `-DFEATURE_STAGE_EDITOR` enables the stage editor.
- `-DFEATURE_LOGGER` logs everything* that's it.

Example:

```bat
lime test windows -debug -DFEATURE_POLYMOD_MODS
```

## 5. Troubleshooting

- If Android crashes but desktop works, check `BuildLogs/android/android-readable-latest.log`.
- If Android has missing Lime primitives, rebuild Lime for Android or check the pinned Lime version.
- If Android builds suddenly fail after SDK changes, make sure you are using JDK 17 and NDK `29.0.13113456`.
- If the app package conflicts with another install, change `PACKAGE_NAME` in `project.hxp`.
