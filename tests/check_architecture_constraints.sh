#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
cd "$ROOT_DIR"

require_command rg "architecture import gates"
require_command python3 "architecture size gates"

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

if rg -n "res://src/battle_core/(actions|commands|effects|lifecycle|logging|math|passives|turn|facades)/" src/battle_core/content src/battle_core/contracts src/battle_core/runtime >/tmp/core_l1_purity.out 2>/dev/null; then
  echo "ARCH_GATE_FAILED: battle_core L1 modules (content/contracts/runtime) must not import upper-layer services" >&2
  cat /tmp/core_l1_purity.out
  rm -f /tmp/core_l1_purity.out
  exit 1
fi
rm -f /tmp/core_l1_purity.out

if rg -n "res://src/battle_core/(actions|effects|lifecycle|passives|turn|facades|runtime)/" src/battle_core/math src/battle_core/commands >/tmp/core_l2_purity.out 2>/dev/null; then
  echo "ARCH_GATE_FAILED: battle_core commands/math layer must remain L2-pure and must not import runtime/coordinators/orchestrators/facades" >&2
  cat /tmp/core_l2_purity.out
  rm -f /tmp/core_l2_purity.out
  exit 1
fi
rm -f /tmp/core_l2_purity.out

if rg -n "res://src/battle_core/facades/" src/battle_core/actions src/battle_core/commands src/battle_core/content src/battle_core/contracts src/battle_core/effects src/battle_core/lifecycle src/battle_core/logging src/battle_core/math src/battle_core/passives src/battle_core/runtime src/battle_core/turn >/tmp/core_facade_leaks.out 2>/dev/null; then
  echo "ARCH_GATE_FAILED: inner battle_core modules must not import facades" >&2
  cat /tmp/core_facade_leaks.out
  rm -f /tmp/core_facade_leaks.out
  exit 1
fi
rm -f /tmp/core_facade_leaks.out

if rg -n "res://src/battle_core/commands/" src/adapters scenes >/tmp/outer_command_imports.out 2>/dev/null; then
  if rg -v "res://src/battle_core/commands/command_types.gd" /tmp/outer_command_imports.out >/tmp/outer_command_imports_filtered.out 2>/dev/null; then
    echo "ARCH_GATE_FAILED: adapters/scenes must not import battle_core commands except command_types.gd" >&2
    cat /tmp/outer_command_imports_filtered.out
    rm -f /tmp/outer_command_imports.out /tmp/outer_command_imports_filtered.out
    exit 1
  fi
fi
rm -f /tmp/outer_command_imports.out /tmp/outer_command_imports_filtered.out

python3 - <<'PY'
from pathlib import Path
import sys

root = Path(".")

size_review_rules = {}

decisions_text = (root / "docs/records/decisions.md").read_text(encoding="utf-8")

review_required = []
warning_review = []
for source_root in [root / "src/battle_core", root / "src/composition"]:
    for path in source_root.rglob("*.gd"):
        rel = str(path.relative_to(root))
        line_count = len(path.read_text(encoding="utf-8").splitlines())
        if 220 <= line_count <= 250:
            warning_review.append((rel, line_count))
        if line_count > 250:
            review_required.append((rel, line_count))

missing_review_allowlist = []
for rel, line_count in review_required:
    if rel not in size_review_rules:
        missing_review_allowlist.append((rel, line_count))

if missing_review_allowlist:
    print("ARCH_GATE_FAILED: core files >250 lines require fresh split or explicit temporary allowlist:", file=sys.stderr)
    for rel, line_count in missing_review_allowlist:
        print(f"  - {rel} ({line_count} lines)", file=sys.stderr)
    sys.exit(1)

stale_allowlist = sorted(set(size_review_rules.keys()) - {rel for rel, _line_count in review_required})
if stale_allowlist:
    print("ARCH_GATE_FAILED: remove stale large-file allowlist entries that no longer exceed 250 lines:", file=sys.stderr)
    for rel in stale_allowlist:
        print(f"  - {rel}", file=sys.stderr)
    sys.exit(1)

allowlist_overflow = []
for rel, line_count in review_required:
    max_lines = int(size_review_rules[rel]["max_lines"])
    if line_count > max_lines:
        allowlist_overflow.append((rel, line_count, max_lines))

if allowlist_overflow:
    print("ARCH_GATE_FAILED: allowlisted files exceeded temporary max_lines cap:", file=sys.stderr)
    for rel, line_count, max_lines in allowlist_overflow:
        print(f"  - {rel} ({line_count} lines > {max_lines})", file=sys.stderr)
    sys.exit(1)

missing_decision_notes = []
for rel, _line_count in review_required:
    if rel not in decisions_text:
        missing_decision_notes.append(rel)

if missing_decision_notes:
    print("ARCH_GATE_FAILED: allowlisted large files must be explicitly recorded in docs/records/decisions.md:", file=sys.stderr)
    for rel in missing_decision_notes:
        print(f"  - {rel}", file=sys.stderr)
    sys.exit(1)

if warning_review:
    print("ARCH_GATE_WARNING: core files approaching 250-line review threshold:")
    for rel, line_count in warning_review:
        print(f"  - {rel} ({line_count} lines)")

for path in (root / "tests").rglob("*.gd"):
    rel = str(path.relative_to(root))
    line_count = len(path.read_text(encoding="utf-8").splitlines())
    if line_count > 600:
        print(f"ARCH_GATE_FAILED: test file exceeds 600 lines: {rel} ({line_count})", file=sys.stderr)
        sys.exit(1)

print("ARCH_GATE_PASSED: outer/internal layering and size constraints are satisfied")
PY
