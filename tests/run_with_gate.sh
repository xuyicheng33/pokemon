#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
LOG_FILE="$(mktemp)"
BOOT_LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE" "$BOOT_LOG_FILE"' EXIT
ENGINE_ERROR_PATTERN='SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|Failed loading resource|Failed to instantiate script|Cannot open file '\''res://'
ENGINE_WARNING_PATTERN='^WARNING:'
APP_FAILURE_PATTERN='BATTLE_SANDBOX_FAILED:'

cd "$ROOT_DIR"

require_command godot "running gdUnit4 suites"
require_command rg "scanning engine error logs"
require_command python3 "running static gate scripts"

status=0
bash tests/run_gdunit.sh >"$LOG_FILE" 2>&1 || status=$?

cat "$LOG_FILE"

if rg -q "$ENGINE_ERROR_PATTERN" "$LOG_FILE"; then
  echo "ENGINE_GATE_FAILED: found engine error logs" >&2
  rg -n "$ENGINE_ERROR_PATTERN" "$LOG_FILE" >&2 || true
  exit 1
fi

if rg -q "$ENGINE_WARNING_PATTERN" "$LOG_FILE"; then
  echo "ENGINE_GATE_FAILED: found engine warnings during tests" >&2
  rg -n "$ENGINE_WARNING_PATTERN" "$LOG_FILE" >&2 || true
  exit 1
fi

if [[ $status -ne 0 ]]; then
  echo "TEST_GATE_FAILED: gdUnit run exited with status $status" >&2
  exit "$status"
fi

boot_status=0
godot --headless --path . --quit-after 20 >"$BOOT_LOG_FILE" 2>&1 || boot_status=$?

cat "$BOOT_LOG_FILE"

if rg -q "$ENGINE_ERROR_PATTERN" "$BOOT_LOG_FILE"; then
  echo "ENGINE_GATE_FAILED: found engine error logs during boot smoke" >&2
  rg -n "$ENGINE_ERROR_PATTERN" "$BOOT_LOG_FILE" >&2 || true
  exit 1
fi

if rg -q "$ENGINE_WARNING_PATTERN" "$BOOT_LOG_FILE"; then
  echo "ENGINE_GATE_FAILED: found engine warnings during boot smoke" >&2
  rg -n "$ENGINE_WARNING_PATTERN" "$BOOT_LOG_FILE" >&2 || true
  exit 1
fi

if rg -q "$APP_FAILURE_PATTERN" "$BOOT_LOG_FILE"; then
  echo "BOOT_GATE_FAILED: found battle sandbox application failure during boot smoke" >&2
  rg -n "$APP_FAILURE_PATTERN" "$BOOT_LOG_FILE" >&2 || true
  exit 1
fi

if [[ $boot_status -ne 0 ]]; then
  echo "BOOT_GATE_FAILED: headless boot smoke exited with status $boot_status" >&2
  exit "$boot_status"
fi

bash tests/check_suite_reachability.sh
bash tests/check_architecture_constraints.sh
bash tests/check_repo_consistency.sh
bash tests/check_sandbox_smoke_matrix.sh

echo "GATE PASSED: gdUnit, boot smoke, suite reachability, architecture constraints, repo consistency, and sandbox smoke matrix are clean"
