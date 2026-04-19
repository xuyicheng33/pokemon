#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"

cd "$ROOT_DIR"

require_command godot "running sandbox smoke matrix"
require_command python3 "validating sandbox smoke summary"

run_case() {
  local label="$1"
  local expected_matchup_id="$2"
  local expected_p1_mode="$3"
  local expected_p2_mode="$4"
  shift 4

  local log_file
  log_file="$(mktemp)"
  local status=0
  "$@" >"$log_file" 2>&1 || status=$?
  cat "$log_file"
  if [[ $status -ne 0 ]]; then
    echo "SANDBOX_SMOKE_FAILED: ${label} exited with status ${status}" >&2
    rm -f "$log_file"
    exit "$status"
  fi

  python3 - "$label" "$log_file" "$expected_matchup_id" "$expected_p1_mode" "$expected_p2_mode" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

label = sys.argv[1]
log_path = Path(sys.argv[2])
expected_matchup_id = sys.argv[3]
expected_p1_mode = sys.argv[4]
expected_p2_mode = sys.argv[5]

json_line = None
for raw_line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
    line = raw_line.strip()
    if line.startswith("{") and line.endswith("}"):
        json_line = line

if json_line is None:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} missing summary JSON")

try:
    payload = json.loads(json_line)
except Exception as exc:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} invalid summary JSON: {exc}")

required_keys = [
    "matchup_id",
    "battle_seed",
    "p1_control_mode",
    "p2_control_mode",
    "winner_side_id",
    "reason",
    "result_type",
    "turn_index",
    "event_log_cursor",
    "command_steps",
]
missing_keys = [key for key in required_keys if key not in payload]
if missing_keys:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} missing keys: {', '.join(missing_keys)}")

if payload["matchup_id"] != expected_matchup_id:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} matchup drifted: {payload['matchup_id']} != {expected_matchup_id}")
if payload["p1_control_mode"] != expected_p1_mode:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} P1 mode drifted: {payload['p1_control_mode']} != {expected_p1_mode}")
if payload["p2_control_mode"] != expected_p2_mode:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} P2 mode drifted: {payload['p2_control_mode']} != {expected_p2_mode}")
if int(payload["battle_seed"]) <= 0:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} invalid battle_seed: {payload['battle_seed']}")
if not str(payload["reason"]).strip():
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} reason is empty")
if not str(payload["result_type"]).strip():
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} result_type is empty")
if payload["result_type"] == "win" and not str(payload["winner_side_id"]).strip():
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} win result requires non-empty winner_side_id")
if payload["result_type"] in ("draw", "no_winner") and str(payload["winner_side_id"]).strip():
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} {payload['result_type']} result must keep winner_side_id empty")
if int(payload["turn_index"]) <= 0:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} invalid turn_index: {payload['turn_index']}")
if int(payload["event_log_cursor"]) <= 0:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} invalid event_log_cursor: {payload['event_log_cursor']}")
if int(payload["command_steps"]) <= 0:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} invalid command_steps: {payload['command_steps']}")

print(
    "SANDBOX_SMOKE_CASE_PASSED: "
    f"{label} matchup={payload['matchup_id']} "
    f"modes={payload['p1_control_mode']}/{payload['p2_control_mode']} "
    f"turn={payload['turn_index']} commands={payload['command_steps']}"
)
PY

  rm -f "$log_file"
}

run_demo_case() {
  local label="$1"
  local expected_profile_id="$2"
  local expected_matchup_id="$3"
  local expected_battle_seed="$4"
  shift 4

  local log_file
  log_file="$(mktemp)"
  local status=0
  "$@" >"$log_file" 2>&1 || status=$?
  cat "$log_file"
  if [[ $status -ne 0 ]]; then
    echo "SANDBOX_SMOKE_FAILED: ${label} exited with status ${status}" >&2
    rm -f "$log_file"
    exit "$status"
  fi

  python3 - "$label" "$log_file" "$expected_profile_id" "$expected_matchup_id" "$expected_battle_seed" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

label = sys.argv[1]
log_path = Path(sys.argv[2])
expected_profile_id = sys.argv[3]
expected_matchup_id = sys.argv[4]
expected_battle_seed = int(sys.argv[5])

json_line = None
for raw_line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
    line = raw_line.strip()
    if line.startswith("{") and line.endswith("}"):
        json_line = line

if json_line is None:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} missing summary JSON")

try:
    payload = json.loads(json_line)
except Exception as exc:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} invalid summary JSON: {exc}")

required_keys = [
    "demo_profile_id",
    "matchup_id",
    "battle_seed",
    "p1_control_mode",
    "p2_control_mode",
    "turn_index",
    "event_log_cursor",
    "command_steps",
]
missing_keys = [key for key in required_keys if key not in payload]
if missing_keys:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} missing keys: {', '.join(missing_keys)}")

if payload["demo_profile_id"] != expected_profile_id:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} profile drifted: {payload['demo_profile_id']} != {expected_profile_id}")
if payload["matchup_id"] != expected_matchup_id:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} matchup drifted: {payload['matchup_id']} != {expected_matchup_id}")
if int(payload["battle_seed"]) != expected_battle_seed:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} battle_seed drifted: {payload['battle_seed']} != {expected_battle_seed}")
if int(payload["turn_index"]) <= 0:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} invalid turn_index: {payload['turn_index']}")
if int(payload["event_log_cursor"]) <= 0:
    raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} invalid event_log_cursor: {payload['event_log_cursor']}")

print(
    "SANDBOX_SMOKE_CASE_PASSED: "
    f"{label} demo={payload['demo_profile_id']} "
    f"matchup={payload['matchup_id']} seed={payload['battle_seed']} "
    f"turn={payload['turn_index']} events={payload['event_log_cursor']}"
)
PY

  rm -f "$log_file"
}

run_case \
  "default_manual_policy" \
  "gojo_vs_sample" \
  "manual" \
  "policy" \
  godot --headless --path . --script tests/helpers/manual_battle_full_run.gd

run_case \
  "kashimo_manual_policy" \
  "kashimo_vs_sample" \
  "manual" \
  "policy" \
  env MATCHUP_ID=kashimo_vs_sample P1_MODE=manual P2_MODE=policy \
  godot --headless --path . --script tests/helpers/manual_battle_full_run.gd

run_case \
  "gojo_policy_policy" \
  "gojo_vs_sample" \
  "policy" \
  "policy" \
  env P1_MODE=policy P2_MODE=policy \
  godot --headless --path . --script tests/helpers/manual_battle_full_run.gd

run_case \
  "gojo_manual_manual" \
  "gojo_vs_sample" \
  "manual" \
  "manual" \
  env P1_MODE=manual P2_MODE=manual \
  godot --headless --path . --script tests/helpers/manual_battle_full_run.gd

run_demo_case \
  "legacy_demo_replay" \
  "legacy" \
  "sample_default" \
  "17" \
  env DEMO_PROFILE=legacy \
  godot --headless --path . --script tests/helpers/demo_replay_full_run.gd

run_demo_case \
  "kashimo_demo_replay" \
  "kashimo" \
  "kashimo_vs_sample" \
  "9101" \
  env DEMO_PROFILE=kashimo \
  godot --headless --path . --script tests/helpers/demo_replay_full_run.gd

echo "SANDBOX_SMOKE_MATRIX_PASSED: manual/manual, manual/policy, policy/policy, and demo replay paths are stable"
