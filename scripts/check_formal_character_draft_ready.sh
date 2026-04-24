#!/usr/bin/env bash
# Validate formal character drafts before moving them into live project paths.
# Usage: bash scripts/check_formal_character_draft_ready.sh [drafts_dir]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/check_formal_character_draft_ready.py" "$@"
