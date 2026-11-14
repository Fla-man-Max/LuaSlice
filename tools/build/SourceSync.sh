#!/usr/bin/env bash
set -euo pipefail
task_source=$(realpath -e "${1:?source directory required}")
task_destination=$(realpath -m "${2:?build cache directory required}")
case "$task_destination" in /|/home|/root|/opt|/tmp|/mnt|/mnt/c) echo 'Refusing a broad cache directory.' >&2; exit 1;; esac
case "$task_destination/" in "$task_source/"*) echo 'The cache must be outside the source directory.' >&2; exit 1;; esac
case "$task_source/" in "$task_destination/"*) echo 'The cache cannot contain the source directory.' >&2; exit 1;; esac
mkdir -p "$task_destination"
task_marker="$task_destination/.fnf-build-cache"
if [[ -f "$task_marker" ]]; then
    test "$(cat "$task_marker")" == "$task_source" || { echo 'This cache belongs to a different source folder.' >&2; exit 1; }
else
    if [[ -n $(find "$task_destination" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
        if [[ ! -L "$task_destination/source" ]] || [[ $(realpath -m "$task_destination/source") != "$task_source/source" ]]; then
            echo 'Choose an empty build cache. Existing unowned files will not be deleted.' >&2
            exit 1
        fi
    fi
    printf '%s\n' "$task_source" > "$task_marker"
fi
task_options=()
while IFS= read -r -d '' task_link; do
    task_relative=${task_link##*/}
    if [[ -e "$task_source/$task_relative" ]] && [[ $(realpath -m "$task_link") == $(realpath -m "$task_source/$task_relative") ]]; then
        task_options+=("--exclude=/$task_relative")
    fi
done < <(find "$task_destination" -mindepth 1 -maxdepth 1 -type l -print0)
rsync -ac --delete "${task_options[@]}" --exclude='.fnf-build-cache' --exclude='.git' --exclude='.github' \
    --exclude='.haxelib' --exclude='.haxelib-donor-link' --exclude='.hmm-bootstrap' --exclude='.research' \
    --exclude='.libraries' --exclude='.work' --exclude='export' --exclude='astc-textures' --exclude='.env' \
    --exclude='*.jks' --exclude='*.keystore' --exclude='signing.properties' "$task_source/" "$task_destination/"
