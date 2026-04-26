#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
cd "$ROOT_DIR"

require_command python3 "suite reachability gate"

python3 - <<'PY'
from pathlib import Path
import json
import sys

root = Path(".")
required_suite_paths: set[str] = set()
profile_manifest_path = root / "tests/suite_profiles.json"

try:
    manifest_payload = json.loads((root / "config/formal_character_manifest.json").read_text(encoding="utf-8"))
except Exception as exc:  # pragma: no cover - gate error path
    print(f"SUITE_REACHABILITY_FAILED: invalid manifest json: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(manifest_payload, dict):
    print("SUITE_REACHABILITY_FAILED: config/formal_character_manifest.json expects top-level dictionary", file=sys.stderr)
    sys.exit(1)

characters = manifest_payload.get("characters", [])
if not isinstance(characters, list):
    print("SUITE_REACHABILITY_FAILED: config/formal_character_manifest.json expects top-level characters array", file=sys.stderr)
    sys.exit(1)

for entry in characters:
    if not isinstance(entry, dict):
        continue
    suite_path = str(entry.get("suite_path", ""))
    if suite_path:
        required_suite_paths.add(suite_path)
    for rel_path in entry.get("required_suite_paths", []):
        if isinstance(rel_path, str) and rel_path:
            required_suite_paths.add(rel_path)

for rel_path in sorted(required_suite_paths):
    if not (root / rel_path).exists():
        print(f"SUITE_REACHABILITY_FAILED: missing required_suite_path {rel_path}", file=sys.stderr)
        sys.exit(1)

all_suite_paths = {
    str(path.relative_to(root))
    for path in (root / "test").rglob("*.gd")
    if path.name != "gdunit_suite_bridge.gd"
}
gdunit_suite_paths = {
    rel_path
    for rel_path in all_suite_paths
    if rel_path.endswith("suite.gd")
}

try:
    suite_profile_payload = json.loads(profile_manifest_path.read_text(encoding="utf-8"))
except Exception as exc:  # pragma: no cover - gate error path
    print(f"SUITE_REACHABILITY_FAILED: invalid suite profile json: {exc}", file=sys.stderr)
    sys.exit(1)

suite_profiles = suite_profile_payload.get("suite_profiles", {})
if not isinstance(suite_profiles, dict):
    print("SUITE_REACHABILITY_FAILED: tests/suite_profiles.json expects suite_profiles object", file=sys.stderr)
    sys.exit(1)

allowed_profiles = {"quick", "extended", "manual"}
seen_quick = 0
for rel_path, profile in sorted(suite_profiles.items()):
    if not isinstance(rel_path, str) or not isinstance(profile, str):
        print("SUITE_REACHABILITY_FAILED: tests/suite_profiles.json expects string suite path -> profile entries", file=sys.stderr)
        sys.exit(1)
    if profile not in allowed_profiles:
        print(f"SUITE_REACHABILITY_FAILED: invalid suite profile {profile} for {rel_path}", file=sys.stderr)
        sys.exit(1)
    if rel_path not in gdunit_suite_paths:
        print(f"SUITE_REACHABILITY_FAILED: suite profile references missing suite {rel_path}", file=sys.stderr)
        sys.exit(1)
    if profile == "quick":
        seen_quick += 1

missing_profile_paths = sorted(gdunit_suite_paths - set(suite_profiles.keys()))
if missing_profile_paths:
    print("SUITE_REACHABILITY_FAILED: gdUnit suites missing suite profile assignment:", file=sys.stderr)
    for rel_path in missing_profile_paths:
        print(f"  - {rel_path}", file=sys.stderr)
    sys.exit(1)

if seen_quick == 0:
    print("SUITE_REACHABILITY_FAILED: tests/suite_profiles.json must keep at least one quick suite", file=sys.stderr)
    sys.exit(1)

legacy_style = []
for rel_path in sorted(all_suite_paths):
    text = (root / rel_path).read_text(encoding="utf-8")
    if "register_tests(" in text:
        legacy_style.append(rel_path)
if legacy_style:
    print("SUITE_REACHABILITY_FAILED: gdUnit suite tree still contains legacy register_tests protocol:", file=sys.stderr)
    for rel_path in legacy_style:
        print(f"  - {rel_path}", file=sys.stderr)
    sys.exit(1)

missing_required = sorted(required_suite_paths - all_suite_paths)
if missing_required:
    print("SUITE_REACHABILITY_FAILED: manifest required suite paths are missing from gdUnit tree:", file=sys.stderr)
    for rel_path in missing_required:
        print(f"  - {rel_path}", file=sys.stderr)
    sys.exit(1)

profile_counts = {profile: 0 for profile in sorted(allowed_profiles)}
for profile in suite_profiles.values():
    profile_counts[profile] += 1
print(
    "SUITE_REACHABILITY_PASSED: manifest suite paths exist under test/, suite profiles are complete, "
    "and no gdUnit suite keeps register_tests (%s)" % ", ".join(
        f"{profile}={profile_counts[profile]}" for profile in sorted(profile_counts)
    )
)
PY
