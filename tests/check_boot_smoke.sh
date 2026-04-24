#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
source "$ROOT_DIR/tests/godot_headless_env.sh"

setup_godot_headless_home

LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"; cleanup_godot_headless_home' EXIT

ENGINE_ERROR_PATTERN='^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|Failed loading resource|Failed to instantiate script|Cannot open file '\''res://'
ENGINE_WARNING_PATTERN='^WARNING:'
APP_FAILURE_PATTERN='BATTLE_SANDBOX_FAILED:'

cd "$ROOT_DIR"

require_command godot "running boot smoke"
require_command rg "scanning boot smoke logs"

status=0
godot --headless --path . --quit-after 20 >"$LOG_FILE" 2>&1 || status=$?

cat "$LOG_FILE"

if rg -q "$ENGINE_ERROR_PATTERN" "$LOG_FILE"; then
  ENGINE_ERROR_FILE="$(mktemp)"
  rg -n "$ENGINE_ERROR_PATTERN" "$LOG_FILE" >"$ENGINE_ERROR_FILE" || true
  if rg -v "ERROR: Can't create shader cache folder, no shader caching will happen: user://" "$ENGINE_ERROR_FILE" >/dev/null; then
    echo "ENGINE_GATE_FAILED: found engine error logs during boot smoke" >&2
    rg -v "ERROR: Can't create shader cache folder, no shader caching will happen: user://" "$ENGINE_ERROR_FILE" >&2 || true
    rm -f "$ENGINE_ERROR_FILE"
    exit 1
  fi
  rm -f "$ENGINE_ERROR_FILE"
fi

if rg -q "$ENGINE_WARNING_PATTERN" "$LOG_FILE"; then
  echo "ENGINE_GATE_FAILED: found engine warnings during boot smoke" >&2
  rg -n "$ENGINE_WARNING_PATTERN" "$LOG_FILE" >&2 || true
  exit 1
fi

if rg -q "$APP_FAILURE_PATTERN" "$LOG_FILE"; then
  echo "BOOT_GATE_FAILED: found battle sandbox application failure during boot smoke" >&2
  rg -n "$APP_FAILURE_PATTERN" "$LOG_FILE" >&2 || true
  exit 1
fi

if [[ $status -ne 0 ]]; then
  echo "BOOT_GATE_FAILED: headless boot smoke exited with status $status" >&2
  exit "$status"
fi

echo "BOOT_SMOKE_PASSED: headless boot smoke is clean"
