#!/usr/bin/env bash
# Scaffold a new formal character.
# Usage: bash scripts/new_formal_character.sh <character_id> <display_name> [--pair-token TOKEN]
#
# Example:
#   bash scripts/new_formal_character.sh itadori_yuji "虎杖悠仁" --pair-token itadori

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/new_formal_character.py" "$@"
