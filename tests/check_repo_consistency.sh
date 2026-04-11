#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
cd "$ROOT_DIR"

require_command python3 "repository consistency gate"
require_command godot "exporting formal delivery registry view for repository consistency gate"

for gate_path in \
  tests/gates/repo_consistency_surface_gate.py \
  tests/gates/repo_consistency_formal_character_gate.py \
  tests/gates/repo_consistency_docs_gate.py
do
  python3 "$gate_path"
done

echo "REPO_CONSISTENCY_PASSED: surface wiring, formal registry, and contract docs are aligned"
