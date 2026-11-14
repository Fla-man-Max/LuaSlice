#!/usr/bin/env bash
set -euo pipefail
task_mode=${1:?setup or build required}
task_source=${2:?source folder required}
task_configuration=${3:-release}
task_name=${4:-Funkin}
task_id=$(printf '%s' "$task_source" | sha256sum | cut -c1-16)
task_build=${5:-${XDG_CACHE_HOME:-$HOME/.cache}/fnf-builds/$task_id}
task_tools=${6:-${XDG_CACHE_HOME:-$HOME/.cache}/fnf-build-tools}
if [[ "$task_build" == - ]]; then task_build=${XDG_CACHE_HOME:-$HOME/.cache}/fnf-builds/$task_id; fi
if [[ "$task_tools" == - ]]; then task_tools=${XDG_CACHE_HOME:-$HOME/.cache}/fnf-build-tools; fi
case "$task_mode" in setup|build) ;; *) echo 'Unknown Linux mode' >&2; exit 1;; esac
case "$task_configuration" in release|debug) ;; *) echo 'Unknown configuration' >&2; exit 1;; esac
case "$task_name" in LuaSlice|Funkin) ;; *) echo 'Unknown game name' >&2; exit 1;; esac
test -f "$task_source/project.hxp"
test -f "$task_source/hmm.json"
if [[ "$task_mode" == setup ]]; then
    task_sudo=()
    if [[ $(id -u) -ne 0 ]]; then task_sudo=(sudo); fi
    "${task_sudo[@]}" apt-get update
    "${task_sudo[@]}" apt-get install -y curl git rsync ca-certificates build-essential cmake ninja-build pkg-config libgc1 libpcre3 libpcre2-8-0 \
      libx11-dev libxi-dev libxext-dev libxinerama-dev libxrandr-dev libgl1-mesa-dev libxss-dev libxv-dev libxxf86vm-dev \
      libdrm-dev libwayland-dev libxkbcommon-dev libpipewire-0.3-dev libdecor-0-dev libibus-1.0-dev \
      libasound2-dev libpulse-dev libudev-dev libgtk-3-dev gamemode-dev libvlc-dev libvlccore-dev vlc-plugin-base
    if [[ -e "$task_source/.git" ]]; then git -C "$task_source" submodule update --init --recursive; fi
    test -d "$task_source/assets/preload" || { echo 'Official assets are missing. Include the assets submodule before setup.' >&2; exit 1; }
    test -f "$task_source/art/readme.txt" || { echo 'Official art is missing. Include the art submodule before setup.' >&2; exit 1; }
    mkdir -p "$task_tools/haxe" "$task_tools/neko" "$task_tools/haxelib"
    if [[ ! -x "$task_tools/haxe/haxe" ]]; then
        curl --fail --location --retry 3 'https://github.com/HaxeFoundation/haxe/releases/download/4.3.7/haxe-4.3.7-linux64.tar.gz' -o "$task_tools/haxe.tar.gz"
        tar -xzf "$task_tools/haxe.tar.gz" --strip-components=1 -C "$task_tools/haxe"
    fi
    if [[ ! -x "$task_tools/neko/neko" ]]; then
        curl --fail --location --retry 3 'https://github.com/HaxeFoundation/neko/releases/download/v2-4-1/neko-2.4.1-linux64.tar.gz' -o "$task_tools/neko.tar.gz"
        tar -xzf "$task_tools/neko.tar.gz" --strip-components=1 -C "$task_tools/neko"
    fi
fi
export PATH="$task_tools/haxe:$task_tools/neko:$PATH"
export LD_LIBRARY_PATH="$task_tools/neko:${LD_LIBRARY_PATH:-}"
export HAXEPATH="$task_tools/haxe" HAXE_STD_PATH="$task_tools/haxe/std" NEKOPATH="$task_tools/neko"
export HXCPP_COMPILE_THREADS=${HXCPP_COMPILE_THREADS:-4}
test -x "$task_tools/haxe/haxe" || { echo 'Run Setup for Linux first.' >&2; exit 1; }
test "$(haxe --version)" == 4.3.7
mkdir -p "$task_build"
bash "$(dirname "$0")/SourceSync.sh" "$task_source" "$task_build"
cd "$task_build"
if [[ "$task_mode" == setup ]]; then
    mkdir -p "$task_build/.haxelib"
    export HAXELIB_PATH="$task_build/.haxelib"
    if ! haxelib path hmm >/dev/null 2>&1; then haxelib install hmm 3.1.0 --always --quiet; fi
    haxelib run hmm install
    while IFS= read -r -d '' task_git; do
        git -C "${task_git%/.git}" submodule update --init --recursive
    done < <(find .haxelib -mindepth 3 -maxdepth 3 -name .git -type d -print0)
    (cd .haxelib/hxcpp/git/tools/hxcpp && haxe compile.hxml)
    haxelib run lime rebuild linux -release
    echo 'Linux setup complete.'
    exit 0
fi
export HAXELIB_PATH="$task_build/.haxelib"
test -d .haxelib || { echo 'Linux project libraries are missing. Run Setup for Linux.' >&2; exit 1; }
haxelib run lime build linux -64 "-$task_configuration"
task_bin="$task_build/export/$task_configuration/linux/bin"
test -x "$task_bin/$task_name"
task_output="$task_source/export/$task_configuration/linux/bin"
if [[ "$task_build" != "$task_source" ]]; then
    mkdir -p "$task_output"
    test "$(realpath -m "$task_output")" == "$(realpath -m "$task_source")/export/$task_configuration/linux/bin"
    rsync -ac --delete "$task_bin/" "$task_output/"
fi
task_archive="$task_source/export/$task_configuration/$task_name-linux-x64.tar.gz"
tar -C "$task_bin" -czf "$task_archive.partial" .
tar -tzf "$task_archive.partial" >/dev/null
mv -f -- "$task_archive.partial" "$task_archive"
echo "Linux build: $task_output"
echo "Linux archive: $task_archive"
