#!/usr/bin/env bash

require_command() {
  local command_name="$1"
  local purpose="$2"
  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi
  echo "TEST_PREREQ_MISSING: requires '$command_name' for $purpose" >&2
  exit 1
}
