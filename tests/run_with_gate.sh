#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"

cd "$ROOT_DIR"

require_command python3 "running static gate scripts"

bash tests/check_gdunit_gate.sh
bash tests/check_boot_smoke.sh
bash tests/check_suite_reachability.sh
bash tests/check_architecture_constraints.sh
bash tests/check_repo_consistency.sh
bash tests/check_python_lint.sh
bash tests/check_sandbox_smoke_matrix.sh

echo "GATE PASSED: gdUnit, boot smoke, suite reachability, architecture constraints, repo consistency, Python lint, and sandbox smoke matrix are clean"
