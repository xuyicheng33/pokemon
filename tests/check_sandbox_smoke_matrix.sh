#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
source "$ROOT_DIR/tests/godot_headless_env.sh"

cd "$ROOT_DIR"

setup_godot_headless_home

require_command godot "running sandbox smoke matrix"
require_command python3 "validating sandbox smoke summary"
require_command rg "scanning sandbox smoke logs"

ENGINE_ERROR_PATTERN='^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|Failed loading resource|Failed to instantiate script|Cannot open file '\''res://'
ENGINE_WARNING_PATTERN='^WARNING:'
ALLOWED_SHADER_CACHE_ERROR="ERROR: Can't create shader cache folder, no shader caching will happen: user://"

SMOKE_CATALOG_FILE="$(mktemp)"
SMOKE_CATALOG_DUMP="$(mktemp)"
trap 'rm -f "$SMOKE_CATALOG_FILE" "$SMOKE_CATALOG_DUMP"; cleanup_godot_headless_home' EXIT

godot --headless --path . --script tests/helpers/export_sandbox_smoke_catalog.gd -- "$SMOKE_CATALOG_FILE"

python3 tests/helpers/sandbox_smoke_catalog.py dump "$SMOKE_CATALOG_FILE" >"$SMOKE_CATALOG_DUMP"

DEFAULT_MATCHUP_ID=""
VISIBLE_MATCHUP_IDS=()
RECOMMENDED_MATCHUP_IDS=()
QUICK_ANCHOR_MATCHUP_IDS=()
DEMO_PROFILE_ROWS=()

current_key=""
while IFS= read -r raw_line; do
  if [[ -z "$raw_line" ]]; then
    current_key=""
    continue
  fi
  if [[ "$raw_line" == "KEY "* ]]; then
    current_key="${raw_line#KEY }"
    continue
  fi
  case "$current_key" in
    default_matchup_id)
      DEFAULT_MATCHUP_ID="$raw_line"
      ;;
    visible_matchup_ids)
      VISIBLE_MATCHUP_IDS+=("$raw_line")
      ;;
    recommended_matchup_ids)
      RECOMMENDED_MATCHUP_IDS+=("$raw_line")
      ;;
    quick_anchor_matchup_ids)
      QUICK_ANCHOR_MATCHUP_IDS+=("$raw_line")
      ;;
    demo_profiles)
      DEMO_PROFILE_ROWS+=("$raw_line")
      ;;
  esac
done <"$SMOKE_CATALOG_DUMP"

if [[ -z "$DEFAULT_MATCHUP_ID" ]]; then
  echo "SANDBOX_SMOKE_FAILED: missing default_matchup_id from sandbox smoke catalog" >&2
  exit 1
fi

if [[ ${#VISIBLE_MATCHUP_IDS[@]} -eq 0 ]]; then
  echo "SANDBOX_SMOKE_FAILED: sandbox smoke catalog exported no visible_matchup_ids" >&2
  exit 1
fi

if [[ ${#RECOMMENDED_MATCHUP_IDS[@]} -eq 0 ]]; then
  echo "SANDBOX_SMOKE_FAILED: sandbox smoke catalog exported no recommended_matchup_ids" >&2
  exit 1
fi

if [[ ${#QUICK_ANCHOR_MATCHUP_IDS[@]} -eq 0 ]]; then
  echo "SANDBOX_SMOKE_FAILED: sandbox smoke catalog exported no quick_anchor_matchup_ids" >&2
  exit 1
fi

if [[ ${#DEMO_PROFILE_ROWS[@]} -eq 0 ]]; then
  echo "SANDBOX_SMOKE_FAILED: sandbox smoke catalog exported no demo_profiles" >&2
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
RUN_PLAYER_MVP_DEFAULT=false
RUN_PLAYER_MVP_QUICK_ANCHORS=false

case "$SANDBOX_SMOKE_SCOPE" in
  quick)
    RUN_QUICK_ANCHOR_MANUAL_POLICY=true
    RUN_DEFAULT_DEMO=true
    RUN_PLAYER_MVP_DEFAULT=true
    ;;
  extended)
    RUN_OTHER_VISIBLE_MANUAL_POLICY=true
    RUN_DEFAULT_POLICY_POLICY=true
    RUN_DEFAULT_MANUAL_MANUAL=true
    RUN_OTHER_DEMO=true
    RUN_PLAYER_MVP_QUICK_ANCHORS=true
    ;;
  full)
    RUN_QUICK_ANCHOR_MANUAL_POLICY=true
    RUN_OTHER_VISIBLE_MANUAL_POLICY=true
    RUN_DEFAULT_POLICY_POLICY=true
    RUN_DEFAULT_MANUAL_MANUAL=true
    RUN_DEFAULT_DEMO=true
    RUN_OTHER_DEMO=true
    RUN_PLAYER_MVP_QUICK_ANCHORS=true
    ;;
esac

QUICK_ANCHOR_LOOKUP=" ${QUICK_ANCHOR_MATCHUP_IDS[*]} "

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
  scan_engine_log "$label" "$log_file"
  if [[ $status -ne 0 ]]; then
    echo "SANDBOX_SMOKE_FAILED: ${label} exited with status ${status}" >&2
    rm -f "$log_file"
    exit "$status"
  fi

  python3 tests/helpers/sandbox_smoke_catalog.py validate-summary \
    "$label" "$log_file" "$expected_matchup_id" "$expected_p1_mode" "$expected_p2_mode"

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
  scan_engine_log "$label" "$log_file"
  if [[ $status -ne 0 ]]; then
    echo "SANDBOX_SMOKE_FAILED: ${label} exited with status ${status}" >&2
    rm -f "$log_file"
    exit "$status"
  fi

  python3 tests/helpers/sandbox_smoke_catalog.py validate-demo-summary \
    "$label" "$log_file" "$expected_profile_id" "$expected_matchup_id" "$expected_battle_seed"

  rm -f "$log_file"
}

# replay case runner（domain / kashimo / obito）：以 SceneTree 入口跑固定案例，
# 验证（1）退出码 0；（2）所有期望的 case 名都出现在 stdout；（3）没有
# BATTLE_*_CASE_FAILED: marker。Domain / kashimo runner 只做 deterministic
# 数据 dump（具体断言走 gdUnit suite）；Obito runner 在内部带 baseline vs
# guarded 对照断言，失败时 quit(1)。
run_replay_case_runner() {
  local label="$1"
  local script_path="$2"
  shift 2
  local expected_cases=("$@")

  local log_file
  log_file="$(mktemp)"
  local status=0
  env CASE=all godot --headless --path . --script "$script_path" >"$log_file" 2>&1 || status=$?
  cat "$log_file"
  scan_engine_log "$label" "$log_file"
  if [[ $status -ne 0 ]]; then
    echo "SANDBOX_SMOKE_FAILED: ${label} exited with status ${status}" >&2
    rm -f "$log_file"
    exit "$status"
  fi
  if rg -q "BATTLE_[A-Z]+_CASE_FAILED:" "$log_file"; then
    echo "SANDBOX_SMOKE_FAILED: ${label} reported case failure marker" >&2
    rg -n "BATTLE_[A-Z]+_CASE_FAILED:" "$log_file" >&2 || true
    rm -f "$log_file"
    exit 1
  fi
  for expected_case in "${expected_cases[@]}"; do
    if ! rg -q "^${expected_case} " "$log_file"; then
      echo "SANDBOX_SMOKE_FAILED: ${label} missing expected case: ${expected_case}" >&2
      rm -f "$log_file"
      exit 1
    fi
  done
  echo "SANDBOX_SMOKE_CASE_PASSED: ${label} cases=${#expected_cases[@]}"
  rm -f "$log_file"
}

scan_engine_log() {
  local label="$1"
  local log_file="$2"
  if rg -q "$ENGINE_ERROR_PATTERN" "$log_file"; then
    local engine_error_file
    engine_error_file="$(mktemp)"
    rg -n "$ENGINE_ERROR_PATTERN" "$log_file" >"$engine_error_file" || true
    if rg -v "$ALLOWED_SHADER_CACHE_ERROR" "$engine_error_file" >/dev/null; then
      echo "ENGINE_GATE_FAILED: ${label} found engine error logs during sandbox smoke" >&2
      rg -v "$ALLOWED_SHADER_CACHE_ERROR" "$engine_error_file" >&2 || true
      rm -f "$engine_error_file"
      exit 1
    fi
    rm -f "$engine_error_file"
  fi
  if rg -q "$ENGINE_WARNING_PATTERN" "$log_file"; then
    echo "ENGINE_GATE_FAILED: ${label} found engine warnings during sandbox smoke" >&2
    rg -n "$ENGINE_WARNING_PATTERN" "$log_file" >&2 || true
    exit 1
  fi
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

# Player MVP 段：以 PlayerBattleSession + PlayerDefaultPolicy 双侧 policy 模式
# 走 player_mvp_full_run.gd，验证 scenes/player/* 与 src/adapters/player/* 的端到端
# 闭环不漂移。validate-summary 复用 manual_battle_full_run.gd 的 JSON 形态（字段一致）。
if $RUN_PLAYER_MVP_DEFAULT; then
  run_case \
    "case_label=${SANDBOX_SMOKE_SCOPE}:player_mvp_default:${DEFAULT_MATCHUP_ID}" \
    "$DEFAULT_MATCHUP_ID" \
    "policy" \
    "policy" \
    env MATCHUP_ID="$DEFAULT_MATCHUP_ID" \
    godot --headless --path . --script tests/helpers/player_mvp_full_run.gd
fi

if $RUN_PLAYER_MVP_QUICK_ANCHORS; then
  for matchup_id in "${QUICK_ANCHOR_MATCHUP_IDS[@]}"; do
    run_case \
      "case_label=${SANDBOX_SMOKE_SCOPE}:player_mvp_anchor:${matchup_id}" \
      "$matchup_id" \
      "policy" \
      "policy" \
      env MATCHUP_ID="$matchup_id" \
      godot --headless --path . --script tests/helpers/player_mvp_full_run.gd
  done
fi

# Replay case runner 段：固定 deterministic 案例进 quick gate。所有 scope 都跑
# 同一组（quick / extended / full 不分级，因为这些案例单次跑成本低且必须每次过）。
run_replay_case_runner \
  "case_label=${SANDBOX_SMOKE_SCOPE}:replay_cases:domain" \
  "tests/helpers/domain_case_runner.gd" \
  "gojo_domain_success" \
  "sukuna_domain_break" \
  "tied_domain_clash" \
  "normal_field_blocked_by_domain" \
  "same_turn_dual_domain_clash"

run_replay_case_runner \
  "case_label=${SANDBOX_SMOKE_SCOPE}:replay_cases:kashimo" \
  "tests/helpers/kashimo_case_runner.gd" \
  "charge_loop" \
  "amber_switch_retention" \
  "kyokyo_vs_domain"

run_replay_case_runner \
  "case_label=${SANDBOX_SMOKE_SCOPE}:replay_cases:obito" \
  "tests/helpers/obito_case_runner.gd" \
  "yinyang_dun_segment_guard"

echo "SANDBOX_SMOKE_MATRIX_PASSED: ${SANDBOX_SMOKE_SCOPE} scope smoke cases (quick anchors=${#QUICK_ANCHOR_MATCHUP_IDS[@]}, visible=${#VISIBLE_MATCHUP_IDS[@]}, demos=${#DEMO_PROFILE_ROWS[@]}) are stable"
echo "NOTE: manual smoke covers BattleSandboxController.submit_action on visible matchups; deterministic action choice still uses BattleSandboxFirstLegalPolicy"
echo "NOTE: player_mvp smoke covers PlayerBattleSession + PlayerDefaultPolicy 双侧 policy via tests/helpers/player_mvp_full_run.gd"
echo "NOTE: scope semantics — quick=每 formal 角色 1 个 manual/policy + 默认 demo replay + 默认 player_mvp; extended=quick 之外的余量 + 4 个 player_mvp anchors; full=全集 superset."
