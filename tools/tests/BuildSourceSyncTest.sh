#!/usr/bin/env bash
set -euo pipefail
task_helper=$(realpath "$(dirname "$0")/../build/SourceSync.sh")
test -f "$task_helper" || { echo 'Source sync implementation is missing.' >&2; exit 1; }
task_tmp=$(mktemp -d /tmp/fnf-sync-test.XXXXXX)
trap '[[ "$task_tmp" == /tmp/fnf-sync-test.* ]] && rm -r -- "$task_tmp"' EXIT
mkdir -p "$task_tmp/source/group" "$task_tmp/cache"
printf 'current' > "$task_tmp/source/current.txt"
printf 'live' > "$task_tmp/source/group/live.txt"
bash "$task_helper" "$task_tmp/source" "$task_tmp/cache"
test "$(cat "$task_tmp/cache/current.txt")" == current
mkdir -p "$task_tmp/cache/.haxelib" "$task_tmp/cache/export"
printf 'keep' > "$task_tmp/cache/.haxelib/library"
printf 'keep' > "$task_tmp/cache/export/build"
printf 'obsolete' > "$task_tmp/cache/obsolete.txt"
rm "$task_tmp/source/group/live.txt"
printf 'changed' > "$task_tmp/source/current.txt"
bash "$task_helper" "$task_tmp/source" "$task_tmp/cache"
test ! -e "$task_tmp/cache/obsolete.txt"
test ! -e "$task_tmp/cache/group/live.txt"
test "$(cat "$task_tmp/cache/current.txt")" == changed
test "$(cat "$task_tmp/cache/.haxelib/library")" == keep
test "$(cat "$task_tmp/cache/export/build")" == keep
rmdir "$task_tmp/cache/group"
ln -s "$task_tmp/source/group" "$task_tmp/cache/group"
printf 'live again' > "$task_tmp/source/group/live.txt"
bash "$task_helper" "$task_tmp/source" "$task_tmp/cache"
test -L "$task_tmp/cache/group"
test "$(cat "$task_tmp/cache/group/live.txt")" == 'live again'
if bash "$task_helper" "$task_tmp/source" "$task_tmp/source"; then echo 'Accepted source as delete target' >&2; exit 1; fi
mkdir "$task_tmp/unknown"
printf 'user data' > "$task_tmp/unknown/personal.txt"
if bash "$task_helper" "$task_tmp/source" "$task_tmp/unknown"; then echo 'Accepted unowned directory' >&2; exit 1; fi
test "$(cat "$task_tmp/unknown/personal.txt")" == 'user data'
echo 'Build source synchronization: passed.'
