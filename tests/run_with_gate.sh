#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"' EXIT
ENGINE_ERROR_PATTERN='SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|Failed loading resource|Failed to instantiate script|Cannot open file '\''res://'

cd "$ROOT_DIR"

status=0
godot --headless --path . --script tests/run_all.gd >"$LOG_FILE" 2>&1 || status=$?

cat "$LOG_FILE"

if rg -q "$ENGINE_ERROR_PATTERN" "$LOG_FILE"; then
  echo "ENGINE_GATE_FAILED: found engine error logs" >&2
  rg -n "$ENGINE_ERROR_PATTERN" "$LOG_FILE" >&2 || true
  exit 1
fi

if [[ $status -ne 0 ]]; then
  echo "TEST_GATE_FAILED: run_all exited with status $status" >&2
  exit "$status"
fi

bash tests/check_suite_reachability.sh
bash tests/check_architecture_constraints.sh
bash tests/check_repo_consistency.sh

echo "GATE PASSED: assertions, suite reachability, engine errors, and static contracts are clean"
