#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"

cd "$ROOT_DIR"

require_command ruff "linting Python scripts and gates"

ruff check scripts/ tests/gates/ tests/helpers/sandbox_smoke_catalog.py --select E,F,W --ignore E501

echo "PYTHON_LINT_PASSED: scripts and gate Python files are clean"
