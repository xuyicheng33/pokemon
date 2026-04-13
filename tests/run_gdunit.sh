#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
cd "$ROOT_DIR"

require_command godot "running gdUnit4 suites"

REPORT_DIR="${REPORT_DIR:-reports/gdunit}"
TEST_PATH="${TEST_PATH:-res://test}"
GODOT_BIN_PATH="${GODOT_BIN:-$(command -v godot)}"

mkdir -p "$REPORT_DIR"

"$GODOT_BIN_PATH" --editor --headless --path . --quit >/dev/null 2>&1

if command -v xvfb-run >/dev/null 2>&1; then
	xvfb-run -a "$GODOT_BIN_PATH" --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--continue \
		-a "$TEST_PATH" \
		-rd "$REPORT_DIR" \
		-rc 1 \
		"$@"
else
	"$GODOT_BIN_PATH" --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--continue \
		-a "$TEST_PATH" \
		-rd "$REPORT_DIR" \
		-rc 1 \
		"$@"
fi

godot --headless --path . --quiet -s res://addons/gdUnit4/bin/GdUnitCopyLog.gd \
	-rd "$REPORT_DIR" \
	"$@" >/dev/null
