#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from pathlib import Path
import json
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


def require_exists(rel_path: str, label: str) -> None:
    if not (root / rel_path).exists():
        failures.append(f"missing {label}: {rel_path}")


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


def load_json_array(rel_path: str, label: str) -> list[dict]:
    try:
        payload = json.loads(read_text(rel_path))
    except Exception as exc:  # pragma: no cover - gate error path
        failures.append(f"{rel_path} invalid {label}: {exc}")
        return []
    if not isinstance(payload, list):
        failures.append(f"{rel_path} invalid {label}: expected top-level array")
        return []
    result: list[dict] = []
    for idx, raw_entry in enumerate(payload):
        if not isinstance(raw_entry, dict):
            failures.append(f"{rel_path} invalid {label}[{idx}]: expected object")
            continue
        result.append(raw_entry)
    return result


src_count = gd_line_count("src")
tests_count = gd_line_count("tests")
total_count = src_count + tests_count
formal_character_registry = load_json_array("docs/records/formal_character_registry.json", "formal character registry")
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
require_contains("tests/run_all.gd", 'const UltimateFieldSuiteScript := preload("res://tests/suites/ultimate_field_suite.gd")', "ultimate field suite registration")
require_contains("tests/run_all.gd", "UltimateFieldSuiteScript.new()", "ultimate field suite execution")
require_contains("tests/run_all.gd", 'const FormalCharacterRegistryScript := preload("res://tests/support/formal_character_registry.gd")', "formal character registry loader")
require_contains("tests/run_all.gd", "FormalCharacterRegistryScript.new().build_suite_instances()", "formal character suite expansion")
require_contains("tests/support/formal_character_registry.gd", 'const REGISTRY_PATH := "res://docs/records/formal_character_registry.json"', "formal character registry path")
require_contains("tests/support/formal_character_registry.gd", 'load("res://%s" % suite_path)', "formal character suite dynamic load")
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
require_contains("tests/suites/content_index_split_suite.gd", 'runner.run_test("content_snapshot_recursive_contract"', "recursive snapshot contract regression")

for rel_path in [
    "docs/design/domain_field_template.md",
    "tests/replay_cases/domain_cases.md",
    "tests/helpers/domain_case_runner.gd",
]:
    require_exists(rel_path, "shared character asset doc")

if not formal_character_registry:
    failures.append("docs/records/formal_character_registry.json must list at least one formal character")
sample_factory_text = read_text("src/composition/sample_battle_factory.gd")
for entry in formal_character_registry:
    character_id = str(entry.get("character_id", ""))
    unit_definition_id = str(entry.get("unit_definition_id", ""))
    design_doc = str(entry.get("design_doc", ""))
    adjustment_doc = str(entry.get("adjustment_doc", ""))
    suite_path = str(entry.get("suite_path", ""))
    required_content_paths = entry.get("required_content_paths", [])
    required_suite_paths = entry.get("required_suite_paths", [])
    required_test_names = entry.get("required_test_names", [])
    design_needles = entry.get("design_needles", [])
    adjustment_needles = entry.get("adjustment_needles", [])
    suite_scope_paths: list[str] = []
    if character_id == "":
        failures.append("formal character registry entry missing character_id")
        continue
    if unit_definition_id == "":
        failures.append(f"formal character registry[{character_id}] missing unit_definition_id")
    if design_doc == "":
        failures.append(f"formal character registry[{character_id}] missing design_doc")
    else:
        require_exists(design_doc, f"{character_id} design doc")
    if adjustment_doc == "":
        failures.append(f"formal character registry[{character_id}] missing adjustment_doc")
    else:
        require_exists(adjustment_doc, f"{character_id} adjustment doc")
    if suite_path == "":
        failures.append(f"formal character registry[{character_id}] missing suite_path")
    else:
        require_exists(suite_path, f"{character_id} suite")
        suite_scope_paths.append(suite_path)
    if not isinstance(required_suite_paths, list) or not required_suite_paths:
        failures.append(f"formal character registry[{character_id}] missing required_suite_paths")
    else:
        for rel_path in required_suite_paths:
            require_exists(str(rel_path), f"{character_id} required suite")
            suite_scope_paths.append(str(rel_path))
    if not isinstance(required_test_names, list) or not required_test_names:
        failures.append(f"formal character registry[{character_id}] missing required_test_names")
    else:
        for test_name in required_test_names:
            require_contains_any(
                suite_scope_paths,
                'runner.run_test("%s"' % str(test_name),
                f"{character_id} regression anchor",
            )
    if not isinstance(required_content_paths, list) or not required_content_paths:
        failures.append(f"formal character registry[{character_id}] missing required_content_paths")
    else:
        for rel_path in required_content_paths:
            require_exists(str(rel_path), f"{character_id} content asset")
    if not isinstance(design_needles, list) or not design_needles:
        failures.append(f"formal character registry[{character_id}] missing design_needles")
    elif design_doc != "":
        for needle in design_needles:
            require_contains(design_doc, str(needle), f"{character_id} design anchor")
    if not isinstance(adjustment_needles, list) or not adjustment_needles:
        failures.append(f"formal character registry[{character_id}] missing adjustment_needles")
    elif adjustment_doc != "":
        for needle in adjustment_needles:
            require_contains(adjustment_doc, str(needle), f"{character_id} adjustment anchor")
    if unit_definition_id != "" and unit_definition_id not in sample_factory_text:
        failures.append(f"src/composition/sample_battle_factory.gd missing formal character wiring: {unit_definition_id}")

require_contains("README.md", "candidate_skill_ids", "README candidate skill pool contract")
require_contains("README.md", "regular_skill_loadout_overrides", "README setup override contract")
require_contains("README.md", "设计稿 + 调整记录 + 内容资源 + SampleFactory 接线 + 角色 suite", "README character delivery workflow")
require_contains("README.md", "docs/records/formal_character_registry.json", "README formal character registry")
require_contains("README.md", "content/battle_formats / combat_types / units / skills / passive_items / effects / fields / passive_skills / samples", "README content snapshot path coverage")
require_absent("README.md", "policy_decision_suite.gd", "removed auto-selection regression workflow")
require_absent("README.md", "gojo_sukuna_batch_probe.gd", "removed batch simulation workflow")
require_contains("docs/design/architecture_overview.md", "get_event_log_snapshot", "architecture facade event log snapshot contract")
require_contains("docs/design/battle_content_schema.md", "candidate_skill_ids", "schema candidate skill pool contract")
require_contains("docs/design/battle_content_schema.md", "regular_skill_loadout_overrides", "schema setup override contract")
require_contains("docs/design/battle_content_schema.md", "required_target_effects", "schema effect precondition contract")
require_contains("docs/design/battle_content_schema.md", "action_legality", "schema action legality contract")
require_contains("docs/design/battle_content_schema.md", "incoming_accuracy", "schema incoming accuracy contract")
require_contains("docs/design/battle_runtime_model.md", "regular_skill_ids", "runtime equipped skill mirror contract")
require_contains("docs/design/battle_runtime_model.md", "action_legality", "runtime action legality contract")
require_contains("docs/design/battle_runtime_model.md", "incoming_accuracy", "runtime incoming accuracy contract")
require_contains("docs/design/command_and_legality.md", "regular_skill_ids", "legality runtime equipped skill contract")
require_contains("docs/design/command_and_legality.md", "domain_legality_service.gd", "domain legality helper doc")
require_contains("docs/design/lifecycle_and_replacement.md", "faint_killer_attribution_service.gd", "lifecycle helper doc")
require_contains("docs/design/lifecycle_and_replacement.md", "faint_leave_replacement_service.gd", "lifecycle replacement helper doc")
require_contains("docs/design/passive_and_field.md", "field_apply_context_resolver.gd", "field helper doc")
require_contains("docs/design/passive_and_field.md", "field_apply_conflict_service.gd", "field conflict helper doc")
require_contains("docs/design/passive_and_field.md", "field_apply_log_service.gd", "field log helper doc")
require_contains("docs/design/passive_and_field.md", "field_apply_effect_runner.gd", "field effect runner helper doc")
require_contains("docs/design/project_folder_structure.md", "facades/", "project folder facades doc")
require_contains("docs/design/architecture_overview.md", "{\"ok\": true, \"data\": ... , \"error_code\": null, \"error_message\": null}", "manager envelope doc")
require_contains("docs/design/sukuna_design.md", "max_stacks = 3", "sukuna kamado hard cap doc")
require_contains("docs/design/sukuna_design.md", "不新增第 4 层", "sukuna kamado overflow ignore doc")
require_contains("docs/rules/01_battle_format_and_visibility.md", "candidate_skill_ids", "rules candidate skill pool contract")
require_contains("docs/rules/01_battle_format_and_visibility.md", "regular_skill_loadout_overrides", "rules setup override contract")
require_contains("docs/rules/06_effect_schema_and_extension.md", "required_target_effects", "rules effect precondition contract")
require_contains("docs/rules/06_effect_schema_and_extension.md", "action_legality", "rules action legality contract")
require_contains("docs/rules/06_effect_schema_and_extension.md", "incoming_accuracy", "rules incoming accuracy contract")
require_contains("docs/rules/03_stats_resources_and_damage.md", "incoming_accuracy", "rules incoming accuracy read-path")
require_contains("docs/design/domain_field_template.md", "field_apply_success", "domain template success trigger contract")
require_contains("docs/design/domain_field_template.md", "同回合双方都已排队施放领域时", "domain template dual-domain contract")
require_contains("tests/README.md", "domain_case_runner.gd", "tests fixed domain case runner doc")
require_contains("tests/README.md", "formal_character_registry.json", "tests formal character registry doc")
require_contains("tests/README.md", "check_suite_reachability.sh", "tests suite reachability gate doc")
require_contains("tests/README.md", "required_suite_paths", "tests registry suite anchor doc")
require_contains("tests/README.md", "required_test_names", "tests registry test anchor doc")
require_contains("tests/replay_cases/domain_cases.md", "CASE=all godot --headless --path . --script tests/helpers/domain_case_runner.gd", "domain case runner command")
require_absent("tests/README.md", "policy_decision_suite.gd", "removed auto-selection suite doc")
require_absent("tests/README.md", "gojo_sukuna_batch_probe.gd", "removed batch simulation doc")
require_contains("tests/run_with_gate.sh", "check_suite_reachability.sh", "suite reachability gate wiring")
require_contains("docs/rules/05_items_field_input_and_logging.md", "当前正式角色交付面不再包含自动选指策略、自动选指回归或批量模拟案例。", "auto-selection removal rule wording")
require_contains("docs/records/decisions.md", "固定可复查案例作为角色与规则复查入口", "fixed-case decision wording")
require_contains("docs/records/decisions.md", "外层输入与公开快照继续只使用 `public_id`。", "public input decision wording")
require_contains("docs/records/decisions.md", "若未来恢复自动选指，必须重新补齐规则、设计文档与接线任务，不得直接回填历史实现。", "future auto-selection recovery gate")
require_contains("docs/records/decisions.md", "effect dedupe key 必须包含 effect_instance_id", "effect-instance dedupe decision wording")
require_contains("docs/records/decisions.md", "field_break / field_expire 链上创建的 successor field 必须保留", "field successor cleanup decision wording")
require_contains("docs/records/decisions.md", "正式角色注册表当前必须登记角色 effect 资源、wrapper 下属 suite 与关键回归测试名", "formal registry expansion decision wording")
require_contains("docs/records/decisions.md", "BattleCoreManager` 公开 contract 统一为严格 envelope", "manager envelope decision wording")
require_contains("docs/records/decisions.md", "宿傩“灶”正式写死为 3 层硬上限，满层后忽略新层", "sukuna kamado cap decision wording")
require_contains("docs/records/decisions.md", "运行时 helper 全部统一进 composition 装配", "runtime helper composition decision wording")
require_contains("tests/suites/sukuna_kamado_domain_suite.gd", 'runner.run_test("sukuna_kamado_stack_cap_path"', "sukuna kamado cap regression")
require_contains("tests/suites/sukuna_kamado_domain_suite.gd", 'runner.run_test("sukuna_kamado_forced_replace_on_exit_path"', "sukuna forced replace kamado regression")
require_contains("tests/suites/sukuna_kamado_domain_suite.gd", 'runner.run_test("sukuna_domain_break_on_faint_path"', "sukuna creator faint field break regression")
require_contains("docs/records/decisions.md", "suite 可达性闸门", "suite reachability decision wording")
require_contains("README.md", "check_suite_reachability.sh", "README suite reachability gate")

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

domain_matrix_redundant_wording = [
    "比较双方**扣费后的当前 MP**；MP 高者留场；平 MP 随机决定胜者",
    "比较双方扣费后的当前 MP；高者留场；平 MP 随机决定胜者",
]
for rel_path in [
    "docs/design/gojo_satoru_design.md",
    "docs/design/sukuna_design.md",
]:
    for needle in domain_matrix_redundant_wording:
        require_absent(rel_path, needle, "role design duplicated public domain matrix wording")

if failures:
    print("REPO_CONSISTENCY_FAILED: repository contracts are drifting", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    sys.exit(1)

print("REPO_CONSISTENCY_PASSED: README stats, regression anchors, and contract docs are aligned")
PY
