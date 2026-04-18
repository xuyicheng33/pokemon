#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"

LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"' EXIT

ENGINE_ERROR_PATTERN='SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|Failed loading resource|Failed to instantiate script|Cannot open file '\''res://'
ENGINE_WARNING_PATTERN='^WARNING:'

cd "$ROOT_DIR"

require_command godot "running gdUnit4 suites"
require_command rg "scanning gdUnit4 engine logs"

status=0
bash tests/run_gdunit.sh >"$LOG_FILE" 2>&1 || status=$?

cat "$LOG_FILE"

if rg -q "$ENGINE_ERROR_PATTERN" "$LOG_FILE"; then
  echo "ENGINE_GATE_FAILED: found engine error logs during gdUnit4" >&2
  rg -n "$ENGINE_ERROR_PATTERN" "$LOG_FILE" >&2 || true
  exit 1
fi

if rg -q "$ENGINE_WARNING_PATTERN" "$LOG_FILE"; then
  echo "ENGINE_GATE_FAILED: found engine warnings during gdUnit4" >&2
  rg -n "$ENGINE_WARNING_PATTERN" "$LOG_FILE" >&2 || true
  exit 1
fi

if [[ $status -ne 0 ]]; then
  echo "TEST_GATE_FAILED: gdUnit run exited with status $status" >&2
  exit "$status"
fi

echo "GDUNIT_GATE_PASSED: gdUnit4 suites and engine log scan are clean"
