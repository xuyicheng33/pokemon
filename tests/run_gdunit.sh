#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
source "$ROOT_DIR/tests/godot_headless_env.sh"
cd "$ROOT_DIR"

setup_godot_headless_home
LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"; cleanup_godot_headless_home' EXIT

REPORT_DIR="${REPORT_DIR:-reports/gdunit}"
TEST_PATH="${TEST_PATH:-res://test}"
GODOT_BIN_PATH="${GODOT_BIN:-$(command -v godot)}"

if [[ -z "$GODOT_BIN_PATH" || ! -x "$GODOT_BIN_PATH" ]]; then
  echo "TEST_PREREQ_MISSING: requires executable GODOT_BIN (current: '${GODOT_BIN_PATH}')" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"
rm -rf "$REPORT_DIR/report_1"

"$GODOT_BIN_PATH" --editor --headless --path . --quit >/dev/null 2>&1

if command -v xvfb-run >/dev/null 2>&1; then
	if xvfb-run -a "$GODOT_BIN_PATH" --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--continue \
		-a "$TEST_PATH" \
		-rd "$REPORT_DIR" \
		-rc 1 \
		"$@" >"$LOG_FILE" 2>&1; then
		status=0
	else
		status=$?
	fi
else
	if "$GODOT_BIN_PATH" --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--continue \
		-a "$TEST_PATH" \
		-rd "$REPORT_DIR" \
		-rc 1 \
		"$@" >"$LOG_FILE" 2>&1; then
		status=0
	else
		status=$?
	fi
fi

cat "$LOG_FILE"

require_command rg "validating gdUnit run output"

if rg -q "No test cases found|Given directory or file does not exists" "$LOG_FILE"; then
	echo "TEST_GATE_FAILED: gdUnit did not execute any test cases for TEST_PATH=$TEST_PATH" >&2
	exit 1
fi

if [[ $status -ne 0 ]]; then
	exit "$status"
fi

"$GODOT_BIN_PATH" --headless --path . --quiet -s res://addons/gdUnit4/bin/GdUnitCopyLog.gd \
	-rd "$REPORT_DIR" \
	"$@" >/dev/null

require_command python3 "validating gdUnit report test count"

python3 - "$REPORT_DIR/report_1/results.xml" "$TEST_PATH" <<'PY'
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

report_path = Path(sys.argv[1])
test_path = sys.argv[2]
if not report_path.exists():
    raise SystemExit(f"TEST_GATE_FAILED: missing gdUnit XML report for TEST_PATH={test_path}: {report_path}")

case_count = 0
root = ET.parse(report_path).getroot()
for _case in root.iter("testcase"):
    case_count += 1

if case_count <= 0:
    raise SystemExit(f"TEST_GATE_FAILED: gdUnit XML report contains 0 test cases for TEST_PATH={test_path}")
PY
