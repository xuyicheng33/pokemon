#!/usr/bin/env bash

setup_godot_headless_home() {
  if [[ -n "${GODOT_HEADLESS_HOME:-}" ]]; then
    return 0
  fi
  GODOT_HEADLESS_HOME="$(mktemp -d "${TMPDIR:-/tmp}/pokemon-godot-home.XXXXXX")"
  mkdir -p "$GODOT_HEADLESS_HOME/.local/share/godot"
  mkdir -p "$GODOT_HEADLESS_HOME/.local/share/godot/app_userdata/pokemon"
  mkdir -p "$GODOT_HEADLESS_HOME/.cache/godot"
  mkdir -p "$GODOT_HEADLESS_HOME/Library/Application Support/Godot"
  mkdir -p "$GODOT_HEADLESS_HOME/Library/Application Support/Godot/app_userdata/pokemon"
  mkdir -p "$GODOT_HEADLESS_HOME/Library/Application Support/Godot/shader_cache"
  export HOME="$GODOT_HEADLESS_HOME"
  export GODOT_USER_HOME="$GODOT_HEADLESS_HOME"
  export XDG_CACHE_HOME="$GODOT_HEADLESS_HOME/.cache"
}

cleanup_godot_headless_home() {
  if [[ -n "${GODOT_HEADLESS_HOME:-}" && -d "$GODOT_HEADLESS_HOME" ]]; then
    rm -rf "$GODOT_HEADLESS_HOME"
  fi
  unset GODOT_HEADLESS_HOME
  unset GODOT_USER_HOME
  unset XDG_CACHE_HOME
}
