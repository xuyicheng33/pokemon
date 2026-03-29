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


def require_contains_any(rel_paths: list[str], needle: str, label: str) -> None:
    for rel_path in rel_paths:
        if needle in read_text(rel_path):
            return
    failures.append(f"{', '.join(rel_paths)} missing {label}: {needle}")


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

require_contains_any(
    [
        "tests/suites/content_logging_suite.gd",
        "tests/suites/log_cause_semantics_suite.gd",
        "tests/suites/log_cause_anchor_suite.gd",
    ],
    "direct damage cause_event_id should point to the real action:hit event",
    "direct damage real cause_event_id regression",
)
require_contains_any(
    [
        "tests/suites/content_logging_suite.gd",
        "tests/suites/log_cause_semantics_suite.gd",
        "tests/suites/log_cause_anchor_suite.gd",
    ],
    "effect event cause_event_id must not point to itself",
    "self-referential cause_event_id regression",
)
require_contains_any(
    [
        "tests/suites/content_logging_suite.gd",
        "tests/suites/log_cause_semantics_suite.gd",
        "tests/suites/log_cause_anchor_suite.gd",
    ],
    "turn_start regen cause_event_id should point to the real system:turn_start anchor",
    "turn_start anchor cause_event_id regression",
)
require_contains_any(
    [
        "tests/suites/content_logging_suite.gd",
        "tests/suites/log_cause_semantics_suite.gd",
        "tests/suites/log_cause_anchor_suite.gd",
    ],
    "field expire cause_event_id should point to the real system:turn_end anchor",
    "field expire anchor cause_event_id regression",
)

require_contains("tests/run_all.gd", 'const SetupLoadoutSuiteScript := preload("res://tests/suites/setup_loadout_suite.gd")', "setup loadout suite registration")
require_contains("tests/run_all.gd", "SetupLoadoutSuiteScript.new()", "setup loadout suite execution")
require_contains("tests/run_all.gd", 'const ExtensionContractSuiteScript := preload("res://tests/suites/extension_contract_suite.gd")', "extension suite registration")
require_contains("tests/run_all.gd", "ExtensionContractSuiteScript.new()", "extension suite execution")
require_contains("tests/run_all.gd", 'const GojoSuiteScript := preload("res://tests/suites/gojo_suite.gd")', "gojo suite registration")
require_contains("tests/run_all.gd", "GojoSuiteScript.new()", "gojo suite execution")
require_contains("tests/run_all.gd", 'const SukunaSuiteScript := preload("res://tests/suites/sukuna_suite.gd")', "sukuna suite registration")
require_contains("tests/run_all.gd", "SukunaSuiteScript.new()", "sukuna suite execution")
require_contains("tests/run_all.gd", 'const UltimateFieldSuiteScript := preload("res://tests/suites/ultimate_field_suite.gd")', "ultimate field suite registration")
require_contains("tests/run_all.gd", "UltimateFieldSuiteScript.new()", "ultimate field suite execution")
require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("candidate_skill_pool_validation"', "candidate skill pool dedicated regression")
require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("setup_loadout_override_validation"', "setup override dedicated regression")
require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("runtime_regular_skill_loadout_contract"', "runtime loadout dedicated regression")
require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("same_side_duplicate_unit_forbidden"', "same-side duplicate unit regression")
require_contains("tests/suites/gojo_murasaki_suite.gd", 'runner.run_test("gojo_murasaki_double_mark_burst_contract"', "gojo burst regression")
require_contains("tests/suites/gojo_domain_suite.gd", 'runner.run_test("gojo_mugen_incoming_accuracy_contract"', "gojo mugen regression")
require_contains("tests/suites/gojo_domain_suite.gd", 'runner.run_test("gojo_unlimited_void_runtime_contract"', "gojo domain regression")
require_contains("tests/suites/sukuna_kamado_domain_suite.gd", 'runner.run_test("sukuna_domain_expire_chain_path"', "sukuna domain expire regression")
require_contains("tests/suites/sukuna_kamado_domain_suite.gd", 'runner.run_test("sukuna_domain_break_chain_path"', "sukuna domain break regression")
require_contains("tests/suites/ultimate_points_contract_suite.gd", 'runner.run_test("ultimate_points_regular_skill_gain_contract"', "ultimate point gain regression")
require_contains("tests/suites/domain_clash_contract_suite.gd", 'runner.run_test("field_clash_tie_replay_contract"', "field clash replay regression")

for rel_path in [
    "docs/design/gojo_satoru_design.md",
    "docs/design/sukuna_design.md",
    "docs/design/gojo_satoru_adjustments.md",
    "docs/design/sukuna_adjustments.md",
]:
    if not (root / rel_path).exists():
        failures.append(f"missing required character asset doc: {rel_path}")

require_contains("README.md", "candidate_skill_ids", "README candidate skill pool contract")
require_contains("README.md", "regular_skill_loadout_overrides", "README setup override contract")
require_contains("README.md", "设计稿 + 调整记录 + 内容资源 + SampleFactory 接线 + 角色 suite", "README character delivery workflow")
require_contains("docs/design/battle_content_schema.md", "candidate_skill_ids", "schema candidate skill pool contract")
require_contains("docs/design/battle_content_schema.md", "regular_skill_loadout_overrides", "schema setup override contract")
require_contains("docs/design/battle_content_schema.md", "required_target_effects", "schema effect precondition contract")
require_contains("docs/design/battle_content_schema.md", "action_legality", "schema action legality contract")
require_contains("docs/design/battle_content_schema.md", "incoming_accuracy", "schema incoming accuracy contract")
require_contains("docs/design/battle_runtime_model.md", "regular_skill_ids", "runtime equipped skill mirror contract")
require_contains("docs/design/battle_runtime_model.md", "action_legality", "runtime action legality contract")
require_contains("docs/design/battle_runtime_model.md", "incoming_accuracy", "runtime incoming accuracy contract")
require_contains("docs/design/command_and_legality.md", "regular_skill_ids", "legality runtime equipped skill contract")
require_contains("docs/rules/01_battle_format_and_visibility.md", "candidate_skill_ids", "rules candidate skill pool contract")
require_contains("docs/rules/01_battle_format_and_visibility.md", "regular_skill_loadout_overrides", "rules setup override contract")
require_contains("docs/rules/06_effect_schema_and_extension.md", "required_target_effects", "rules effect precondition contract")
require_contains("docs/rules/06_effect_schema_and_extension.md", "action_legality", "rules action legality contract")
require_contains("docs/rules/06_effect_schema_and_extension.md", "incoming_accuracy", "rules incoming accuracy contract")
require_contains("docs/rules/03_stats_resources_and_damage.md", "incoming_accuracy", "rules incoming accuracy read-path")
require_contains("docs/design/gojo_satoru_design.md", "on_success_effect_ids", "gojo design domain success-only lock contract")
require_contains("docs/design/gojo_satoru_design.md", "对拼失败", "gojo design field clash failure contract")
require_contains("docs/design/sukuna_design.md", "领域自然到期终爆保留", "sukuna design expire burst contract")
require_contains("docs/design/sukuna_design.md", "3 点奥义点体系下", "sukuna design balance record")
require_contains("docs/design/gojo_satoru_adjustments.md", "影响测试", "gojo adjustment impact fields")
require_contains("docs/design/sukuna_adjustments.md", "影响测试", "sukuna adjustment impact fields")

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
