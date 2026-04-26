#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
source "$ROOT_DIR/tests/godot_headless_env.sh"

cd "$ROOT_DIR"

setup_godot_headless_home

require_command godot "running sandbox smoke matrix"
require_command python3 "validating sandbox smoke summary"

SMOKE_CATALOG_FILE="$(mktemp)"
trap 'rm -f "$SMOKE_CATALOG_FILE"; cleanup_godot_headless_home' EXIT

godot --headless --path . --script tests/helpers/export_sandbox_smoke_catalog.gd -- "$SMOKE_CATALOG_FILE"

DEFAULT_MATCHUP_ID="$(python3 - "$SMOKE_CATALOG_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(str(payload.get("default_matchup_id", "")).strip())
PY
)"

if [[ -z "$DEFAULT_MATCHUP_ID" ]]; then
  echo "SANDBOX_SMOKE_FAILED: missing default_matchup_id from sandbox smoke catalog" >&2
  exit 1
fi

VISIBLE_MATCHUP_IDS=()
while IFS= read -r matchup_id; do
  if [[ -n "$matchup_id" ]]; then
    VISIBLE_MATCHUP_IDS+=("$matchup_id")
  fi
done < <(python3 - "$SMOKE_CATALOG_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for raw_matchup_id in payload.get("visible_matchup_ids", []):
    matchup_id = str(raw_matchup_id).strip()
    if matchup_id:
        print(matchup_id)
PY
)

if [[ ${#VISIBLE_MATCHUP_IDS[@]} -eq 0 ]]; then
  echo "SANDBOX_SMOKE_FAILED: sandbox smoke catalog exported no visible_matchup_ids" >&2
  exit 1
fi

RECOMMENDED_MATCHUP_IDS=()
while IFS= read -r matchup_id; do
  if [[ -n "$matchup_id" ]]; then
    RECOMMENDED_MATCHUP_IDS+=("$matchup_id")
  fi
done < <(python3 - "$SMOKE_CATALOG_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for raw_matchup_id in payload.get("recommended_matchup_ids", []):
    matchup_id = str(raw_matchup_id).strip()
    if matchup_id:
        print(matchup_id)
PY
)

if [[ ${#RECOMMENDED_MATCHUP_IDS[@]} -eq 0 ]]; then
  echo "SANDBOX_SMOKE_FAILED: sandbox smoke catalog exported no recommended_matchup_ids" >&2
  exit 1
fi

QUICK_ANCHOR_MATCHUP_IDS=()
while IFS= read -r matchup_id; do
  if [[ -n "$matchup_id" ]]; then
    QUICK_ANCHOR_MATCHUP_IDS+=("$matchup_id")
  fi
done < <(python3 - "$SMOKE_CATALOG_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for raw_matchup_id in payload.get("quick_anchor_matchup_ids", []):
    matchup_id = str(raw_matchup_id).strip()
    if matchup_id:
        print(matchup_id)
PY
)

if [[ ${#QUICK_ANCHOR_MATCHUP_IDS[@]} -eq 0 ]]; then
  echo "SANDBOX_SMOKE_FAILED: sandbox smoke catalog exported no quick_anchor_matchup_ids" >&2
  exit 1
fi

VISIBLE_MATCHUP_LOOKUP=" ${VISIBLE_MATCHUP_IDS[*]} "
for anchor_id in "${QUICK_ANCHOR_MATCHUP_IDS[@]}"; do
  if [[ "$VISIBLE_MATCHUP_LOOKUP" != *" $anchor_id "* ]]; then
    echo "SANDBOX_SMOKE_FAILED: quick anchor matchup not visible: $anchor_id" >&2
    exit 1
  fi
done

SANDBOX_SMOKE_SCOPE="${SANDBOX_SMOKE_SCOPE:-quick}"
if [[ "$SANDBOX_SMOKE_SCOPE" != "quick" \
   && "$SANDBOX_SMOKE_SCOPE" != "extended" \
   && "$SANDBOX_SMOKE_SCOPE" != "full" ]]; then
  echo "SANDBOX_SMOKE_FAILED: SANDBOX_SMOKE_SCOPE must be quick, extended, or full: $SANDBOX_SMOKE_SCOPE" >&2
  exit 1
fi

RUN_QUICK_ANCHOR_MANUAL_POLICY=false
RUN_OTHER_VISIBLE_MANUAL_POLICY=false
RUN_DEFAULT_POLICY_POLICY=false
RUN_DEFAULT_MANUAL_MANUAL=false
RUN_DEFAULT_DEMO=false
RUN_OTHER_DEMO=false

case "$SANDBOX_SMOKE_SCOPE" in
  quick)
    RUN_QUICK_ANCHOR_MANUAL_POLICY=true
    RUN_DEFAULT_DEMO=true
    ;;
  extended)
    RUN_OTHER_VISIBLE_MANUAL_POLICY=true
    RUN_DEFAULT_POLICY_POLICY=true
    RUN_DEFAULT_MANUAL_MANUAL=true
    RUN_OTHER_DEMO=true
    ;;
  full)
    RUN_QUICK_ANCHOR_MANUAL_POLICY=true
    RUN_OTHER_VISIBLE_MANUAL_POLICY=true
    RUN_DEFAULT_POLICY_POLICY=true
    RUN_DEFAULT_MANUAL_MANUAL=true
    RUN_DEFAULT_DEMO=true
    RUN_OTHER_DEMO=true
    ;;
esac

QUICK_ANCHOR_LOOKUP=" ${QUICK_ANCHOR_MATCHUP_IDS[*]} "

DEMO_PROFILE_ROWS=()
while IFS= read -r demo_row; do
  if [[ -n "$demo_row" ]]; then
    DEMO_PROFILE_ROWS+=("$demo_row")
  fi
done < <(python3 - "$SMOKE_CATALOG_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for raw_profile in payload.get("demo_profiles", []):
    if not isinstance(raw_profile, dict):
        continue
    demo_profile_id = str(raw_profile.get("demo_profile_id", "")).strip()
    matchup_id = str(raw_profile.get("matchup_id", "")).strip()
    battle_seed = int(raw_profile.get("battle_seed", 0))
    if demo_profile_id and matchup_id and battle_seed > 0:
        print(f"{demo_profile_id}\t{matchup_id}\t{battle_seed}")
PY
)

if [[ ${#DEMO_PROFILE_ROWS[@]} -eq 0 ]]; then
  echo "SANDBOX_SMOKE_FAILED: sandbox smoke catalog exported no demo_profiles" >&2
  exit 1
fi

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

if $RUN_QUICK_ANCHOR_MANUAL_POLICY; then
  for matchup_id in "${QUICK_ANCHOR_MATCHUP_IDS[@]}"; do
    run_case \
      "case_label=${SANDBOX_SMOKE_SCOPE}:quick_anchor_manual_policy:${matchup_id}" \
      "$matchup_id" \
      "manual" \
      "policy" \
      env MATCHUP_ID="$matchup_id" P1_MODE=manual P2_MODE=policy \
      godot --headless --path . --script tests/helpers/manual_battle_full_run.gd
  done
fi

if $RUN_OTHER_VISIBLE_MANUAL_POLICY; then
  for matchup_id in "${VISIBLE_MATCHUP_IDS[@]}"; do
    if [[ "$QUICK_ANCHOR_LOOKUP" == *" $matchup_id "* ]]; then
      continue
    fi
    run_case \
      "case_label=${SANDBOX_SMOKE_SCOPE}:other_visible_manual_policy:${matchup_id}" \
      "$matchup_id" \
      "manual" \
      "policy" \
      env MATCHUP_ID="$matchup_id" P1_MODE=manual P2_MODE=policy \
      godot --headless --path . --script tests/helpers/manual_battle_full_run.gd
  done
fi

if $RUN_DEFAULT_POLICY_POLICY; then
  run_case \
    "case_label=${SANDBOX_SMOKE_SCOPE}:default_policy_policy:${DEFAULT_MATCHUP_ID}" \
    "$DEFAULT_MATCHUP_ID" \
    "policy" \
    "policy" \
    env MATCHUP_ID="$DEFAULT_MATCHUP_ID" P1_MODE=policy P2_MODE=policy \
    godot --headless --path . --script tests/helpers/manual_battle_full_run.gd
fi

if $RUN_DEFAULT_MANUAL_MANUAL; then
  run_case \
    "case_label=${SANDBOX_SMOKE_SCOPE}:default_manual_manual:${DEFAULT_MATCHUP_ID}" \
    "$DEFAULT_MATCHUP_ID" \
    "manual" \
    "manual" \
    env MATCHUP_ID="$DEFAULT_MATCHUP_ID" P1_MODE=manual P2_MODE=manual \
    godot --headless --path . --script tests/helpers/manual_battle_full_run.gd
fi

DEFAULT_DEMO_PROFILE_ID=""
if [[ ${#DEMO_PROFILE_ROWS[@]} -gt 0 ]]; then
  IFS=$'\t' read -r DEFAULT_DEMO_PROFILE_ID _ _ <<<"${DEMO_PROFILE_ROWS[0]}"
fi

for demo_row in "${DEMO_PROFILE_ROWS[@]}"; do
  IFS=$'\t' read -r demo_profile_id demo_matchup_id demo_battle_seed <<<"$demo_row"
  if [[ "$demo_profile_id" == "$DEFAULT_DEMO_PROFILE_ID" ]]; then
    if ! $RUN_DEFAULT_DEMO; then
      continue
    fi
    case_kind="default_demo"
  else
    if ! $RUN_OTHER_DEMO; then
      continue
    fi
    case_kind="other_demo"
  fi
  run_demo_case \
    "case_label=${SANDBOX_SMOKE_SCOPE}:${case_kind}_demo_replay:${demo_profile_id}" \
    "$demo_profile_id" \
    "$demo_matchup_id" \
    "$demo_battle_seed" \
    env DEMO_PROFILE="$demo_profile_id" \
    godot --headless --path . --script tests/helpers/demo_replay_full_run.gd
done

echo "SANDBOX_SMOKE_MATRIX_PASSED: ${SANDBOX_SMOKE_SCOPE} scope smoke cases (quick anchors=${#QUICK_ANCHOR_MATCHUP_IDS[@]}, visible=${#VISIBLE_MATCHUP_IDS[@]}, demos=${#DEMO_PROFILE_ROWS[@]}) are stable"
echo "NOTE: manual smoke covers BattleSandboxController.submit_action on visible matchups; deterministic action choice still uses BattleSandboxFirstLegalPolicy"
echo "NOTE: scope semantics — quick=每 formal 角色 1 个 manual/policy + 默认 demo replay; extended=quick 之外的余量; full=全集 superset."
