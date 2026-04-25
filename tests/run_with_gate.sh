#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"

cd "$ROOT_DIR"

require_command python3 "running static gate scripts"

TEST_PROFILE="${TEST_PROFILE:-quick}"
if [[ "$TEST_PROFILE" != "quick" && "$TEST_PROFILE" != "extended" && "$TEST_PROFILE" != "full" ]]; then
  echo "TEST_GATE_FAILED: TEST_PROFILE must be quick, extended, or full: $TEST_PROFILE" >&2
  exit 1
fi

if [[ "$TEST_PROFILE" == "full" ]]; then
  export SANDBOX_SMOKE_SCOPE="${SANDBOX_SMOKE_SCOPE:-full}"
else
  export SANDBOX_SMOKE_SCOPE="${SANDBOX_SMOKE_SCOPE:-quick}"
fi
export TEST_PROFILE

bash tests/check_gdunit_gate.sh
bash tests/check_boot_smoke.sh
bash tests/check_suite_reachability.sh
bash tests/check_architecture_constraints.sh
bash tests/check_repo_consistency.sh
bash tests/check_python_lint.sh
bash tests/check_sandbox_smoke_matrix.sh

echo "GATE PASSED: ${TEST_PROFILE} gdUnit, boot smoke, suite reachability, architecture constraints, repo consistency, Python lint, and sandbox smoke matrix are clean"
