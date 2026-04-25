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

QUICK_TEST_PATHS=(
  "res://test/suites/battle_sandbox_launch_config_contract_suite.gd"
  "res://test/suites/manual_battle_scene/manual_flow_suite.gd"
  "res://test/suites/manual_battle_scene/demo_replay_suite.gd"
  "res://test/suites/gojo_snapshot_suite.gd"
  "res://test/suites/gojo_manager_smoke_suite.gd"
  "res://test/suites/sukuna_snapshot_suite.gd"
  "res://test/suites/sukuna_manager_smoke_suite.gd"
  "res://test/suites/kashimo_snapshot_suite.gd"
  "res://test/suites/kashimo_manager_smoke_suite.gd"
  "res://test/suites/obito_snapshot_suite.gd"
  "res://test/suites/obito_manager_smoke_suite.gd"
  "res://test/suites/sample_battle_factory_contract_suite.gd"
  "res://test/suites/content_validation_core/formal_registry/runtime_registry_suite.gd"
  "res://test/suites/content_validation_core/formal_registry/catalog_factory_setup_suite.gd"
  "res://test/suites/content_validation_core/formal_registry/catalog_factory_surface_suite.gd"
  "res://test/suites/content_validation_core/formal_registry/catalog_factory_delivery_alignment_suite.gd"
  "res://test/suites/formal_character_pair_smoke/surface_suite.gd"
  "res://test/suites/formal_character_pair_smoke/interaction_suite.gd"
  "res://test/suites/manager_replay_header_contract_suite.gd"
  "res://test/suites/replay_content_smoke_suite.gd"
  "res://test/suites/init_matchup_lifecycle_suite.gd"
  "res://test/suites/ultimate_points_contract_suite.gd"
  "res://test/suites/domain_clash_guard_suite.gd"
)

TEST_PATHS=()
if [[ -n "${TEST_PATH:-}" ]]; then
  TEST_PATHS=("$TEST_PATH")
else
  case "$TEST_PROFILE" in
    quick)
      TEST_PATHS=("${QUICK_TEST_PATHS[@]}")
      ;;
    extended|full)
      TEST_PATHS=("res://test")
      ;;
    *)
      echo "TEST_PREREQ_MISSING: TEST_PROFILE must be quick, extended, or full: $TEST_PROFILE" >&2
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
