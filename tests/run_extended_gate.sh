#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

env -u SANDBOX_SMOKE_SCOPE TEST_PROFILE=quick bash tests/run_with_gate.sh
env -u SANDBOX_SMOKE_SCOPE TEST_PROFILE=extended bash tests/run_with_gate.sh
