#!/usr/bin/env bash
# Linux counterpart of setup.ps1: fetch the official Godot 4.7.2 editor build,
# verify its SHA512 and unpack it into .tools/godot/. No-op on other hosts.
set -euo pipefail
[ "$(uname -s)" = "Linux" ] || exit 0
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tool_root="$project_root/.tools"
engine_dir="$tool_root/godot"
binary_name='Godot_v4.7.2-stable_linux.x86_64'
[ -x "$engine_dir/$binary_name" ] && exit 0
mkdir -p "$tool_root"
release='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable'
archive_name="$binary_name.zip"
archive="$tool_root/godot-linux.zip"
sums="$tool_root/godot-linux-SHA512-SUMS.txt"
echo 'Downloading the Godot 4.7.2 editor from its official release...'
curl -fsSL "$release/$archive_name" -o "$archive"
curl -fsSL "$release/SHA512-SUMS.txt" -o "$sums"
line="$(grep -E "[[:space:]]\*?${archive_name//./\\.}\$" "$sums" | tr -d '\r' || true)"
if [ "$(printf '%s\n' "$line" | grep -c .)" -ne 1 ]; then
  echo 'Could not identify the official archive checksum.' >&2; exit 1
fi
expected="$(printf '%s' "$line" | awk '{print tolower($1)}')"
actual="$(sha512sum "$archive" | awk '{print tolower($1)}')"
if [ "$expected" != "$actual" ]; then
  echo 'Godot download checksum failed. Archive was not extracted.' >&2; exit 1
fi
mkdir -p "$engine_dir"
unzip -qo "$archive" -d "$engine_dir"
chmod +x "$engine_dir/$binary_name"
echo 'Godot is ready.'
