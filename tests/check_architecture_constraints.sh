#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
cd "$ROOT_DIR"

require_command python3 "architecture gates"

python3 tests/gates/architecture_composition_consistency_gate.py
python3 tests/gates/architecture_wiring_graph_gate.py
python3 tests/gates/architecture_gdscript_style_gate.py
python3 tests/gates/architecture_layering_gate.py
