#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from pathlib import Path
import re
import sys

root = Path(".")
failures: list[str] = []


def read_text(rel_path: str) -> str:
    return (root / rel_path).read_text(encoding="utf-8")


def require_contains(rel_path: str, needle: str, label: str) -> None:
    if needle not in read_text(rel_path):
        failures.append(f"{rel_path} missing {label}: {needle}")


def require_absent(rel_path: str, needle: str, label: str) -> None:
    if needle in read_text(rel_path):
        failures.append(f"{rel_path} still contains stale {label}: {needle}")


def gd_line_count(top_level_dir: str) -> int:
    total = 0
    for path in sorted((root / top_level_dir).rglob("*.gd")):
        total += path.read_bytes().count(b"\n")
    return total


def require_readme_count(label: str, pattern: str, actual: int) -> None:
    readme_text = read_text("README.md")
    match = re.search(pattern, readme_text)
    if match is None:
        failures.append(f"README.md missing code size entry for {label}")
        return
    documented = int(match.group(1))
    if documented != actual:
        failures.append(f"README.md {label} count mismatch: documented={documented}, actual={actual}")


src_count = gd_line_count("src")
tests_count = gd_line_count("tests")
total_count = src_count + tests_count
require_readme_count("src", r"`src/\*\*/\*\.gd`：`(\d+)` 行", src_count)
require_readme_count("tests", r"`tests/\*\*/\*\.gd`：`(\d+)` 行", tests_count)
require_readme_count("total", r"GDScript 合计：`(\d+)` 行", total_count)

require_contains(
    "tests/suites/content_logging_suite.gd",
    "direct damage cause_event_id should point to the real action:hit event",
    "direct damage real cause_event_id regression",
)
require_contains(
    "tests/suites/content_logging_suite.gd",
    "effect event cause_event_id must not point to itself",
    "self-referential cause_event_id regression",
)
require_contains(
    "tests/suites/content_logging_suite.gd",
    "turn_start regen cause_event_id should point to the real system:turn_start anchor",
    "turn_start anchor cause_event_id regression",
)
require_contains(
    "tests/suites/content_logging_suite.gd",
    "field expire cause_event_id should point to the real system:turn_end anchor",
    "field expire anchor cause_event_id regression",
)

require_contains("tests/run_all.gd", 'const SetupLoadoutSuiteScript := preload("res://tests/suites/setup_loadout_suite.gd")', "setup loadout suite registration")
require_contains("tests/run_all.gd", "SetupLoadoutSuiteScript.new()", "setup loadout suite execution")
require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("candidate_skill_pool_validation"', "candidate skill pool dedicated regression")
require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("setup_loadout_override_validation"', "setup override dedicated regression")
require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("runtime_regular_skill_loadout_contract"', "runtime loadout dedicated regression")

require_contains("README.md", "candidate_skill_ids", "README candidate skill pool contract")
require_contains("README.md", "regular_skill_loadout_overrides", "README setup override contract")
require_contains("docs/design/battle_content_schema.md", "candidate_skill_ids", "schema candidate skill pool contract")
require_contains("docs/design/battle_content_schema.md", "regular_skill_loadout_overrides", "schema setup override contract")
require_contains("docs/design/battle_runtime_model.md", "regular_skill_ids", "runtime equipped skill mirror contract")
require_contains("docs/design/command_and_legality.md", "regular_skill_ids", "legality runtime equipped skill contract")
require_contains("docs/rules/01_battle_format_and_visibility.md", "candidate_skill_ids", "rules candidate skill pool contract")
require_contains("docs/rules/01_battle_format_and_visibility.md", "regular_skill_loadout_overrides", "rules setup override contract")

stale_candidate_wording = [
    "schema 暂不扩候选技能池字段",
    "当前 schema 不单独编码",
    "写死在 README 与内容说明文档里",
]
for rel_path in [
    "README.md",
    "content/README.md",
    "docs/design/battle_content_schema.md",
    "docs/records/decisions.md",
]:
    for needle in stale_candidate_wording:
        require_absent(rel_path, needle, "candidate skill pool drift wording")

if failures:
    print("REPO_CONSISTENCY_FAILED: repository contracts are drifting", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    sys.exit(1)

print("REPO_CONSISTENCY_PASSED: README stats, regression anchors, and contract docs are aligned")
PY
