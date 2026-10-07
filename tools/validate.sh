#!/usr/bin/env bash
# Linux counterpart of validate.ps1: import, sim tests, scene smoke check, docking trial.
set -uo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot="$project_root/.tools/godot/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$godot" ] || "$project_root/tools/setup.sh" || exit 1
[ -x "$godot" ] || { echo "Godot not found at $godot" >&2; exit 1; }

# Godot keeps running after a GDScript error and can still exit 0, so treat any
# script error in the output as a failure too.
run_godot() {
  local label="$1"; shift
  local output code
  output="$("$godot" "$@" 2>&1)"
  code=$?
  printf '%s\n' "$output" | grep -E 'SCRIPT ERROR|^ERROR|checks,|SMOKE_OK|DOCK_TRIAL|FAIL' || true
  if [ "$code" -ne 0 ] || printf '%s\n' "$output" | grep -q 'SCRIPT ERROR'; then
    echo "$label failed" >&2
    exit 1
  fi
}

cd "$project_root" || exit 1
run_godot 'Godot import' --headless --path "$project_root" --editor --import --quit
run_godot 'Sim tests' --headless --path "$project_root" --script res://tests/run_tests.gd
run_godot 'Scene smoke check' --headless --path "$project_root" -- --smoke
run_godot 'Docking trial' --headless --path "$project_root" -- --dock-trial
