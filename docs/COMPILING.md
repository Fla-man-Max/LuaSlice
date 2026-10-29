# Compiling Friday Night Funkin' (From Funkin' Crew)

0. Setup
    - Download Haxe from [Haxe.org](https://haxe.org)
    - Download Git from [git-scm.com](https://www.git-scm.com)
    - Do NOT download the repository using the Download ZIP button on GitHub or you may run into errors!
    - Instead, open a command prompt and do the following steps...
1. Run `cd the\directory\you\want\the\source\code\in` to specify which folder the command prompt is working in.
    - For example, `cd C:\Users\YOURNAME\Documents` would instruct the command prompt to perform the next steps in your Documents folder.
2. Run `git clone https://github.com/FunkinCrew/funkin.git` to clone the base repository.
3. Run `cd funkin` to enter the cloned repository's directory.
4. Run `git submodule update --init --recursive` to download the game's assets.
    - NOTE: By performing this operation, you are downloading Content which is proprietary and protected by national and international copyright and trademark laws. See [the LICENSE.md file for the Funkin.assets](https://github.com/FunkinCrew/funkin.assets/blob/main/LICENSE.md) repo for more information.
5. Run `haxelib --global install hmm` and then `haxelib --global run hmm setup` to install hmm.json
6. Run `hmm install` to install all haxelibs of the current branch
    - If you have issues installing Lime, try utilizing Funkin's patched libraries for hmm and haxelib: `haxelib --global git haxelib https://github.com/FunkinCrew/haxelib.git` and `haxelib --global git hmm  https://github.com/FunkinCrew/hmm.git`
8. Run `haxelib run lime setup` to set up Lime
9. Perform additional platform setup
   - For Windows, download the [Visual Studio Build Tools](https://aka.ms/vs/17/release/vs_BuildTools.exe)
        - When prompted, select "Individual Components" and make sure to download the following:
        - MSVC v143 VS 2022 C++ x64/x86 build tools
        - Windows 10/11 SDK
    - Mac: [`lime setup mac` Documentation](https://lime.openfl.org/docs/advanced-setup/macos/)
    - Linux: [`lime setup linux` Documentation](https://lime.openfl.org/docs/advanced-setup/linux/)
        - One of Funkin's dependencies uses libVLC, which requires you to install some development packages to be able to compile.
          Command for Ubuntu/Debian based systems: `sudo apt install libvlc-dev libvlccore-dev libvlccore9`, and for other distros, please refer to [hxvlc's documentation](https://github.com/MAJigsaw77/hxvlc?tab=readme-ov-file#dependencies)
    - HTML5: Compiles without any extra setup
10. If you are targeting for native, you may need to run `lime rebuild <PLATFORM>` and `lime rebuild <PLATFORM> -debug`
11. `lime test <PLATFORM>` to build and launch the game for your platform (for example, `lime test windows`)

## Build Flags

There are several useful build flags you can add to a build to affect how it works. A full list can be found in `project.hxp`, but here's information on some of them:

- `-debug` to build the game in debug mode. This automatically enables several useful debug features.
    - This includes enabling in-game debug functions, disables compile-time optimizations, enabling asset redirection (see below), and enabling the VSCode debug server (which can slow the game on some machines but allows for powerful debugging through breakpoints).
    - `-DGITHUB_BUILD` will enable in-game debug functions (such as the ability to time travel in a song by pressing `PgUp`/`PgDn`), without enabling the other stuff
- `-DFEATURE_POLYMOD_MODS` or `-DNO_FEATURE_POLYMOD_MODS` to forcibly enable or disable modding support.
- `-DREDIRECT_ASSETS_FOLDER` or `-DNO_REDIRECT_ASSETS_FOLDER` to forcibly enable or disable asset redirection.
    - This feature causes the game to load exported assets from the project's assets folder rather than the exported one. Great for fast iteration, but the game will break if you try to zip it up and send it to someone, so it's disabled for release builds.
- `-DFEATURE_DISCORD_RPC` or `-DNO_FEATURE_DISCORD_RPC` to forcibly enable or disable support for Discord Rich Presence.
- `-DFEATURE_VIDEO_PLAYBACK` or `-DNO_FEATURE_VIDEO_PLAYBACK` to forcibly enable or disable video cutscene support.
- `-DFEATURE_SCREENSHOTS` or `-DNO_FEATURE_SCREENSHOTS` to forcibly enable or disable the screenshots feature.
- `-DFEATURE_CHART_EDITOR` or `-DNO_FEATURE_CHART_EDITOR` to forcibly enable or disable the chart editor in the Debug menu.
- `-DFEATURE_STAGE_EDITOR` to forcibly enable the experimental stage editor.
- `-DFEATURE_GHOST_TAPPING` to forcibly enable an experimental gameplay change to the anti-mash system.

# Troubleshooting

If you experience any issues during the compilation process, DO NOT open an issue on GitHub. Instead, check the [Troubleshooting Guide](TROUBLESHOOTING.md) for steps on how to resolve common problems.

## Linux on Windows

Install WSL/Ubuntu from an administrator terminal with `wsl --install -d Ubuntu`, then restart Windows if requested. Launch Ubuntu once to finish creating its Linux user. Linux builds must run inside Ubuntu, not the Windows command prompt. Use Haxe 4.3.7, Neko 2.4.1 and the dependencies pinned in `hmm.json`.

If Windows Update already has a pending restart, use its **Restart now** button or **Update and restart** first. An ordinary restart can leave those updates deferred, along with the WSL components. Check `wsl --status` before repeating the installation.

On Ubuntu 24.04, install the native build and runtime dependencies:

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake ninja-build pkg-config libgc1 libpcre3 libpcre2-8-0 \
  libx11-dev libxi-dev libxext-dev libxinerama-dev libxrandr-dev libgl1-mesa-dev \
  libxss-dev libxv-dev libxxf86vm-dev libdrm-dev libwayland-dev libxkbcommon-dev \
  libpipewire-0.3-dev libdecor-0-dev libibus-1.0-dev \
  libasound2-dev libpulse-dev libudev-dev libgtk-3-dev gamemode-dev \
  libvlc-dev libvlccore-dev vlc-plugin-base xvfb xauth
```

After installing the Linux native dependencies listed above, install the project libraries with `haxelib --global run hmm install`. If the native Lime libraries are missing, run `haxelib run lime rebuild linux -release` before `haxelib run lime build linux -64 -release`.

The Linux x64 release and automated startup, scripting, converter and editor-playtest checks passed under WSL2 with Ubuntu 24.04. This build requires glibc 2.38 or newer and the libVLC runtime (`libvlc5`, `libvlccore9`, `vlc-plugin-base` on Ubuntu). Keep the executable alongside its `assets`, `manifest` and `lime.ndll` files. Use the `.tar.gz` release archive to preserve executable permissions.

The existing PowerShell regression runner supports Linux too. With PowerShell, Xvfb and the native dependencies installed, run:

```bash
xvfb-run -a pwsh -NoProfile -File tools/tests/TestPsychLua.ps1 -NoMods
xvfb-run -a pwsh -NoProfile -File tools/tests/TestPsychLua.ps1 -CheckConverters
xvfb-run -a pwsh -NoProfile -File tools/tests/TestPsychLua.ps1 -CheckEditor
```

## Manual Linux and iOS cloud builds

`tools/ci/build-linux-ios.yml` is a GitHub Actions workflow template. It is deliberately outside `.github/workflows`, so source sync does not activate it. When ready, copy it to `.github/workflows/build-linux-ios.yml` in your own repository and upload the source you want to build. Include the modified assets and art, not only the stock upstream submodule references.

Run **LuaSlice Linux and iOS** from the repository's Actions tab and select `linux`, `ios` or `all`. There are no push triggers, release publishing steps, signing secrets or write permissions for repository contents. Running it uploads build artifacts and test logs to Actions; private repositories may consume paid runner minutes.

The workflow installs Haxe 4.3.7 and Neko 2.4.1, installs the pinned project libraries and rebuilds their platform-native libraries. The Linux job runs startup, script, converter and editor-playtest regressions before packaging the build. The macOS job builds and launches the iOS simulator app, then builds an unsigned device app. Simulator startup checks do not replace gameplay, touch-control or real-device tests.

Artifacts are `LuaSlice-linux-x64.tar.gz`, `LuaSlice-ios-simulator.zip` and `LuaSlice-ios-unsigned.ipa`. The simulator ZIP cannot be installed on an iPhone. The unsigned IPA still needs signing before installation and is not an App Store release. See [COMPILING_MOBILE.md](COMPILING_MOBILE.md) for iOS signing setup.

The template has not been run on GitHub yet. The Linux release was tested locally under WSL2, but the cloud jobs remain unverified. iOS configuration and workflow syntax checks do not confirm that an iOS app compiles or runs.
