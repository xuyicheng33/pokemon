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
TEST_PROFILE="${TEST_PROFILE:-quick}"
GODOT_BIN_PATH="${GODOT_BIN:-$(command -v godot)}"
SUITE_PROFILE_MANIFEST="tests/suite_profiles.json"

TEST_PATHS=()
if [[ -n "${TEST_PATH:-}" ]]; then
  TEST_PATHS=("$TEST_PATH")
else
  case "$TEST_PROFILE" in
    quick)
      while IFS= read -r test_path; do
        TEST_PATHS+=("$test_path")
      done < <(python3 - "$SUITE_PROFILE_MANIFEST" quick <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
requested_profile = sys.argv[2]
payload = json.loads(manifest_path.read_text(encoding="utf-8"))
suite_profiles = payload.get("suite_profiles", {})
if not isinstance(suite_profiles, dict):
    raise SystemExit(f"TEST_PREREQ_MISSING: {manifest_path} missing suite_profiles object")
suite_paths = sorted(path for path, profile in suite_profiles.items() if profile == requested_profile)
if not suite_paths:
    raise SystemExit(f"TEST_PREREQ_MISSING: no suites declared for TEST_PROFILE={requested_profile} in {manifest_path}")
for path in suite_paths:
    print("res://%s" % path)
PY
      )
      ;;
    extended|full)
      TEST_PATHS=("res://test")
      ;;
    manual)
      while IFS= read -r test_path; do
        TEST_PATHS+=("$test_path")
      done < <(python3 - "$SUITE_PROFILE_MANIFEST" manual <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
requested_profile = sys.argv[2]
payload = json.loads(manifest_path.read_text(encoding="utf-8"))
suite_profiles = payload.get("suite_profiles", {})
if not isinstance(suite_profiles, dict):
    raise SystemExit(f"TEST_PREREQ_MISSING: {manifest_path} missing suite_profiles object")
suite_paths = sorted(path for path, profile in suite_profiles.items() if profile == requested_profile)
if not suite_paths:
    raise SystemExit(f"TEST_GATE_FAILED: no gdUnit suites are marked manual in {manifest_path}")
for path in suite_paths:
    print("res://%s" % path)
PY
      )
      ;;
    *)
      echo "TEST_PREREQ_MISSING: TEST_PROFILE must be quick, extended, full, or manual: $TEST_PROFILE" >&2
      exit 1
      ;;
  esac
fi

if [[ -z "$GODOT_BIN_PATH" || ! -x "$GODOT_BIN_PATH" ]]; then
  echo "TEST_PREREQ_MISSING: requires executable GODOT_BIN (current: '${GODOT_BIN_PATH}')" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"
rm -rf "$REPORT_DIR/report_1"

"$GODOT_BIN_PATH" --editor --headless --path . --quit >/dev/null 2>&1

GDUNIT_ADD_ARGS=()
for test_path in "${TEST_PATHS[@]}"; do
  GDUNIT_ADD_ARGS+=("-a" "$test_path")
done

if command -v xvfb-run >/dev/null 2>&1; then
	if xvfb-run -a "$GODOT_BIN_PATH" --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--continue \
		"${GDUNIT_ADD_ARGS[@]}" \
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
		"${GDUNIT_ADD_ARGS[@]}" \
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
	echo "TEST_GATE_FAILED: gdUnit did not execute any test cases for TEST_PROFILE=$TEST_PROFILE TEST_PATHS=${TEST_PATHS[*]}" >&2
	exit 1
fi

if [[ $status -ne 0 ]]; then
	exit "$status"
fi

"$GODOT_BIN_PATH" --headless --path . --quiet -s res://addons/gdUnit4/bin/GdUnitCopyLog.gd \
	-rd "$REPORT_DIR" \
	"$@" >/dev/null

require_command python3 "validating gdUnit report test count"

python3 - "$REPORT_DIR/report_1/results.xml" "$TEST_PROFILE" "${TEST_PATHS[@]}" <<'PY'
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

report_path = Path(sys.argv[1])
test_profile = sys.argv[2]
test_paths = sys.argv[3:]
if not report_path.exists():
    raise SystemExit(f"TEST_GATE_FAILED: missing gdUnit XML report for TEST_PROFILE={test_profile} TEST_PATHS={test_paths}: {report_path}")

case_count = 0
root = ET.parse(report_path).getroot()
for _case in root.iter("testcase"):
    case_count += 1

if case_count <= 0:
    raise SystemExit(f"TEST_GATE_FAILED: gdUnit XML report contains 0 test cases for TEST_PROFILE={test_profile} TEST_PATHS={test_paths}")
PY
