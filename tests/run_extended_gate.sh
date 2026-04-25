#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

TEST_PROFILE=extended bash tests/check_gdunit_gate.sh
SANDBOX_SMOKE_SCOPE=full bash tests/check_sandbox_smoke_matrix.sh
bash tests/check_suite_reachability.sh
bash tests/check_architecture_constraints.sh
bash tests/check_repo_consistency.sh
bash tests/check_python_lint.sh

echo "EXTENDED_GATE_PASSED: extended gdUnit, full sandbox smoke, suite reachability, architecture, repo consistency, and Python lint are clean"
