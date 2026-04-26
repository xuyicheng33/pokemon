#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

rm -rf \
  reports/gdunit/report_1 \
  reports/gdunit_compose \
  reports/gdunit_gojo_smoke \
  reports/gdunit_manual \
  reports/gdunit_smoke \
  tmp \
  .tmp

find . -type d \( -name "__pycache__" -o -name ".ruff_cache" \) -prune -exec rm -rf {} +

rmdir assets 2>/dev/null || true

echo "LOCAL_ARTIFACT_CLEANUP_PASSED: removed gdUnit reports, scratch directories, and Python caches"
