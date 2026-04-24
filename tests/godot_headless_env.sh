#!/usr/bin/env bash

setup_godot_headless_home() {
  if [[ -n "${GODOT_HEADLESS_HOME:-}" ]]; then
    return 0
  fi
  GODOT_HEADLESS_HOME="$(mktemp -d "${TMPDIR:-/tmp}/pokemon-godot-home.XXXXXX")"
  export HOME="$GODOT_HEADLESS_HOME"
  export GODOT_USER_HOME="$GODOT_HEADLESS_HOME"
}

cleanup_godot_headless_home() {
  if [[ -n "${GODOT_HEADLESS_HOME:-}" && -d "$GODOT_HEADLESS_HOME" ]]; then
    rm -rf "$GODOT_HEADLESS_HOME"
  fi
  unset GODOT_HEADLESS_HOME
  unset GODOT_USER_HOME
}
