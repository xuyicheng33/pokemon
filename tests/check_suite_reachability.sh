#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
cd "$ROOT_DIR"

require_command python3 "suite reachability gate"

python3 - <<'PY'
from pathlib import Path
import json
import re
import sys

root = Path(".")
suite_preload_pattern = re.compile(r'preload\("res://(tests/suites/[^"]+\.gd)"\)')


def read_text(rel_path: str) -> str:
    return (root / rel_path).read_text(encoding="utf-8")


reachable: set[str] = set()
pending: list[str] = []
required_suite_paths: set[str] = set()

run_all_text = read_text("tests/run_all.gd")
pending.extend(suite_preload_pattern.findall(run_all_text))

try:
    registry_payload = json.loads(read_text("docs/records/formal_character_registry.json"))
except Exception as exc:  # pragma: no cover - gate error path
    print(f"SUITE_REACHABILITY_FAILED: invalid registry json: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(registry_payload, list):
    print("SUITE_REACHABILITY_FAILED: formal_character_registry.json expects top-level array", file=sys.stderr)
    sys.exit(1)

for entry in registry_payload:
    if not isinstance(entry, dict):
        continue
    suite_path = str(entry.get("suite_path", ""))
    if suite_path:
        pending.append(suite_path)
    for rel_path in entry.get("required_suite_paths", []):
        if isinstance(rel_path, str) and rel_path:
            required_suite_paths.add(rel_path)

while pending:
    suite_path = pending.pop()
    if suite_path in reachable:
        continue
    if not (root / suite_path).exists():
        print(f"SUITE_REACHABILITY_FAILED: missing suite path {suite_path}", file=sys.stderr)
        sys.exit(1)
    reachable.add(suite_path)
    for child_suite in suite_preload_pattern.findall(read_text(suite_path)):
        pending.append(child_suite)

for rel_path in sorted(required_suite_paths):
    if not (root / rel_path).exists():
        print(f"SUITE_REACHABILITY_FAILED: missing required_suite_path {rel_path}", file=sys.stderr)
        sys.exit(1)
    if rel_path not in reachable:
        print(
            "SUITE_REACHABILITY_FAILED: required_suite_path is not reachable from run_all or registry wrapper: %s"
            % rel_path,
            file=sys.stderr,
        )
        sys.exit(1)

all_suite_paths = {
    str(path.relative_to(root))
    for path in (root / "tests/suites").glob("*.gd")
}
unreachable = sorted(all_suite_paths - reachable)
if unreachable:
    print("SUITE_REACHABILITY_FAILED: suite files are unreachable from run_all/registry:", file=sys.stderr)
    for rel_path in unreachable:
        print(f"  - {rel_path}", file=sys.stderr)
    sys.exit(1)

print("SUITE_REACHABILITY_PASSED: every tests/suites/*.gd file is reachable from run_all/registry")
PY
