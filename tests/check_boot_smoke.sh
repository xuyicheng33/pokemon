#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
source "$ROOT_DIR/tests/godot_headless_env.sh"

setup_godot_headless_home

LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"; cleanup_godot_headless_home' EXIT

ENGINE_ERROR_PATTERN='^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|Failed loading resource|Failed to instantiate script|Cannot open file '\''res://'
ENGINE_WARNING_PATTERN='^WARNING:'
APP_FAILURE_PATTERN='BATTLE_SANDBOX_FAILED:|BATTLE_PLAYER_FAILED:'

cd "$ROOT_DIR"

require_command godot "running boot smoke"
require_command rg "scanning boot smoke logs"

# 单轮 boot smoke 入口：传入 label 与额外的 godot 命令行尾参（用 "--" 分隔的 user_args）。
# 静默 shader 缓存目录的标准 ERROR；其他 ENGINE_ERROR / ENGINE_WARNING / APP_FAILURE 一律 fail-fast。
run_round() {
  local round_label="$1"
  shift

  local status=0
  godot --headless --path . --quit-after 20 "$@" >"$LOG_FILE" 2>&1 || status=$?

  cat "$LOG_FILE"

  if rg -q "$ENGINE_ERROR_PATTERN" "$LOG_FILE"; then
    local engine_error_file
    engine_error_file="$(mktemp)"
    rg -n "$ENGINE_ERROR_PATTERN" "$LOG_FILE" >"$engine_error_file" || true
    if rg -v "ERROR: Can't create shader cache folder, no shader caching will happen: user://" "$engine_error_file" >/dev/null; then
      echo "ENGINE_GATE_FAILED: ${round_label} found engine error logs during boot smoke" >&2
      rg -v "ERROR: Can't create shader cache folder, no shader caching will happen: user://" "$engine_error_file" >&2 || true
      rm -f "$engine_error_file"
      exit 1
    fi
    rm -f "$engine_error_file"
  fi

  if rg -q "$ENGINE_WARNING_PATTERN" "$LOG_FILE"; then
    echo "ENGINE_GATE_FAILED: ${round_label} found engine warnings during boot smoke" >&2
    rg -n "$ENGINE_WARNING_PATTERN" "$LOG_FILE" >&2 || true
    exit 1
  fi

  if rg -q "$APP_FAILURE_PATTERN" "$LOG_FILE"; then
    echo "BOOT_GATE_FAILED: ${round_label} found application failure marker during boot smoke" >&2
    rg -n "$APP_FAILURE_PATTERN" "$LOG_FILE" >&2 || true
    exit 1
  fi

  if [[ $status -ne 0 ]]; then
    echo "BOOT_GATE_FAILED: ${round_label} headless boot smoke exited with status $status" >&2
    exit "$status"
  fi
}

# Round 1：默认 sandbox 入口（Boot.launch_config = "sandbox"）。
run_round "sandbox"

# Round 2：玩家 MVP 入口（通过 -- --player_mvp 在 Boot._open() 切到 BattleScreen.tscn）。
# 这一轮只是验证 BattleScreen 场景与 PlayerBattleSession 装配链不会出 ENGINE_ERROR /
# ENGINE_WARNING / BATTLE_PLAYER_FAILED，整局推进交给 sandbox_smoke_matrix 的 player_mvp 段。
run_round "player_mvp" -- --player_mvp

echo "BOOT_SMOKE_PASSED: headless boot smoke is clean (sandbox + player_mvp)"
