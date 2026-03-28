#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if rg -n "res://src/battle_core/runtime/" src/adapters src/composition scenes >/tmp/runtime_imports.out 2>/dev/null; then
  echo "ARCH_GATE_FAILED: outer layers must not import battle_core/runtime/*" >&2
  cat /tmp/runtime_imports.out
  rm -f /tmp/runtime_imports.out
  exit 1
fi
rm -f /tmp/runtime_imports.out

if rg -n "res://src/battle_core/(actions|content|effects|lifecycle|logging|math|passives|turn)/" src/adapters scenes >/tmp/outer_internal_imports.out 2>/dev/null; then
  echo "ARCH_GATE_FAILED: adapters/scenes must not import battle_core internal services" >&2
  cat /tmp/outer_internal_imports.out
  rm -f /tmp/outer_internal_imports.out
  exit 1
fi
rm -f /tmp/outer_internal_imports.out

python3 - <<'PY'
from pathlib import Path
import sys

root = Path(".")

allowlisted_reviews = {
    "src/battle_core/content/battle_content_index.gd": "content registry/validator remains centralized in prototype stage",
    "src/battle_core/effects/rule_mod_service.gd": "rule_mod stacking schema migration is centralized in one service",
    "src/battle_core/effects/payload_handlers/payload_numeric_handler.gd": "numeric payload semantics (typed fixed damage + percent heal) remain consolidated for fail-fast validation",
    "src/battle_core/turn/battle_initializer.gd": "startup sequencing now also pre-applies first-turn regen; keep centralized until the next bootstrap refactor after Gojo v1 lands",
    "src/battle_core/actions/action_cast_service.gd": "hit resolution now owns field override plus incoming_accuracy read-path; keep centralized until post-Gojo extraction of hit helpers",
}

decisions_text = (root / "docs/records/decisions.md").read_text(encoding="utf-8")

review_required = []
for path in (root / "src/battle_core").rglob("*.gd"):
    rel = str(path.relative_to(root))
    line_count = len(path.read_text(encoding="utf-8").splitlines())
    if line_count > 250:
        review_required.append((rel, line_count))

missing_review_allowlist = []
for rel, line_count in review_required:
    if rel not in allowlisted_reviews:
        missing_review_allowlist.append((rel, line_count))

if missing_review_allowlist:
    print("ARCH_GATE_FAILED: core files >250 lines without review allowlist:", file=sys.stderr)
    for rel, line_count in missing_review_allowlist:
        print(f"  - {rel} ({line_count} lines)", file=sys.stderr)
    sys.exit(1)

missing_decision_notes = []
for rel in allowlisted_reviews:
    if rel not in decisions_text:
        missing_decision_notes.append(rel)

if missing_decision_notes:
    print("ARCH_GATE_FAILED: allowlisted large files must be explicitly recorded in docs/records/decisions.md:", file=sys.stderr)
    for rel in missing_decision_notes:
        print(f"  - {rel}", file=sys.stderr)
    sys.exit(1)

for path in (root / "tests").rglob("*.gd"):
    rel = str(path.relative_to(root))
    line_count = len(path.read_text(encoding="utf-8").splitlines())
    if line_count > 600:
        print(f"ARCH_GATE_FAILED: test file exceeds 600 lines: {rel} ({line_count})", file=sys.stderr)
        sys.exit(1)

print("ARCH_GATE_PASSED: layer/runtime boundary and size constraints are satisfied")
PY
