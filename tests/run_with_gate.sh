#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"' EXIT

cd "$ROOT_DIR"

status=0
godot --headless --path . --script tests/run_all.gd >"$LOG_FILE" 2>&1 || status=$?

cat "$LOG_FILE"

if rg -q "SCRIPT ERROR|Compile Error|Parse Error|Failed to load script" "$LOG_FILE"; then
  echo "ENGINE_GATE_FAILED: found engine error logs" >&2
  exit 1
fi

if [[ $status -ne 0 ]]; then
  echo "TEST_GATE_FAILED: run_all exited with status $status" >&2
  exit "$status"
fi

tests/check_architecture_constraints.sh

echo "GATE PASSED: assertions and engine logs are clean"
