from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


ctx = GateContext()

src_count = ctx.gd_line_count("src")
tests_count = ctx.gd_line_count("tests")
total_count = src_count + tests_count
ctx.require_readme_count("src", r"`src/\*\*/\*\.gd`：`(\d+)` 行", src_count)
ctx.require_readme_count("tests", r"`tests/\*\*/\*\.gd`：`(\d+)` 行", tests_count)
ctx.require_readme_count("total", r"GDScript 合计：`(\d+)` 行", total_count)

ctx.require_contains_any(
    [
        "tests/suites/content_logging_suite.gd",
        "tests/suites/log_cause_semantics_suite.gd",
        "tests/suites/log_cause_anchor_suite.gd",
    ],
    "direct damage cause_event_id should point to the real action:hit event",
    "direct damage real cause_event_id regression",
)
ctx.require_contains_any(
    [
        "tests/suites/content_logging_suite.gd",
        "tests/suites/log_cause_semantics_suite.gd",
        "tests/suites/log_cause_anchor_suite.gd",
    ],
    "effect event cause_event_id must not point to itself",
    "self-referential cause_event_id regression",
)
ctx.require_contains_any(
    [
        "tests/suites/content_logging_suite.gd",
        "tests/suites/log_cause_semantics_suite.gd",
        "tests/suites/log_cause_anchor_suite.gd",
    ],
    "turn_start regen cause_event_id should point to the real system:turn_start anchor",
    "turn_start anchor cause_event_id regression",
)
ctx.require_contains_any(
    [
        "tests/suites/content_logging_suite.gd",
        "tests/suites/log_cause_semantics_suite.gd",
        "tests/suites/log_cause_anchor_suite.gd",
    ],
    "field expire cause_event_id should point to the real system:turn_end anchor",
    "field expire anchor cause_event_id regression",
)

ctx.require_contains("tests/run_all.gd", 'const SetupLoadoutSuiteScript := preload("res://tests/suites/setup_loadout_suite.gd")', "setup loadout suite registration")
ctx.require_contains("tests/run_all.gd", "SetupLoadoutSuiteScript.new()", "setup loadout suite execution")
ctx.require_contains("tests/run_all.gd", 'const ExtensionContractSuiteScript := preload("res://tests/suites/extension_contract_suite.gd")', "extension suite registration")
ctx.require_contains("tests/run_all.gd", "ExtensionContractSuiteScript.new()", "extension suite execution")
ctx.require_contains("tests/run_all.gd", 'const UltimateFieldSuiteScript := preload("res://tests/suites/ultimate_field_suite.gd")', "ultimate field suite registration")
ctx.require_contains("tests/run_all.gd", "UltimateFieldSuiteScript.new()", "ultimate field suite execution")
ctx.require_contains("tests/run_all.gd", 'const FormalCharacterRegistryScript := preload("res://tests/support/formal_character_registry.gd")', "formal character registry loader")
ctx.require_contains("tests/run_all.gd", "FormalCharacterRegistryScript.new().build_suite_instances()", "formal character suite expansion")
ctx.require_contains("tests/support/formal_character_registry.gd", 'const REGISTRY_PATH := "res://docs/records/formal_character_registry.json"', "formal character registry path")
ctx.require_contains("tests/support/formal_character_registry.gd", 'load("res://%s" % suite_path)', "formal character suite dynamic load")
ctx.require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("candidate_skill_pool_validation"', "candidate skill pool dedicated regression")
ctx.require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("setup_loadout_override_validation"', "setup override dedicated regression")
ctx.require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("runtime_regular_skill_loadout_contract"', "runtime loadout dedicated regression")
ctx.require_contains("tests/suites/setup_loadout_suite.gd", 'runner.run_test("same_side_duplicate_unit_forbidden"', "same-side duplicate unit regression")
ctx.require_contains("tests/suites/gojo_murasaki_suite.gd", 'runner.run_test("gojo_murasaki_double_mark_burst_contract"', "gojo burst regression")
ctx.require_contains("tests/suites/gojo_domain_suite.gd", 'runner.run_test("gojo_mugen_incoming_accuracy_contract"', "gojo mugen regression")
ctx.require_contains("tests/suites/gojo_domain_suite.gd", 'runner.run_test("gojo_unlimited_void_runtime_contract"', "gojo domain regression")
ctx.require_contains("tests/suites/sukuna_domain_suite.gd", 'runner.run_test("sukuna_domain_expire_chain_path"', "sukuna domain expire regression")
ctx.require_contains("tests/suites/sukuna_domain_suite.gd", 'runner.run_test("sukuna_domain_break_chain_path"', "sukuna domain break regression")
ctx.require_contains("tests/suites/ultimate_points_contract_suite.gd", 'runner.run_test("ultimate_points_regular_skill_gain_contract"', "ultimate point gain regression")
ctx.require_contains_any(
    [
        "tests/suites/domain_clash_contract_suite.gd",
        "tests/suites/domain_clash_resolution_suite.gd",
        "tests/suites/domain_clash_guard_suite.gd",
    ],
    'runner.run_test("field_clash_tie_replay_contract"',
    "field clash replay regression",
)
ctx.require_contains("tests/suites/content_index_split_suite.gd", 'runner.run_test("content_snapshot_recursive_contract"', "recursive snapshot contract regression")
ctx.require_contains("tests/suites/sukuna_kamado_suite.gd", 'runner.run_test("sukuna_kamado_stack_cap_path"', "sukuna kamado cap regression")
ctx.require_contains("tests/suites/sukuna_kamado_suite.gd", 'runner.run_test("sukuna_kamado_forced_replace_on_exit_path"', "sukuna forced replace kamado regression")
ctx.require_contains("tests/suites/sukuna_domain_suite.gd", 'runner.run_test("sukuna_domain_break_on_faint_path"', "sukuna creator faint field break regression")

for rel_path in [
    "docs/design/domain_field_template.md",
    "tests/replay_cases/domain_cases.md",
    "tests/helpers/domain_case_runner.gd",
]:
    ctx.require_exists(rel_path, "shared character asset doc")

ctx.require_contains("README.md", "candidate_skill_ids", "README candidate skill pool contract")
ctx.require_contains("README.md", "regular_skill_loadout_overrides", "README setup override contract")
ctx.require_contains("README.md", "设计稿 + 调整记录 + 内容资源 + SampleFactory 接线 + 角色 suite", "README character delivery workflow")
ctx.require_contains("README.md", "docs/records/formal_character_registry.json", "README formal character registry")
ctx.require_contains("README.md", "content/battle_formats / combat_types / units / skills / passive_items / effects / fields / passive_skills / samples", "README content snapshot path coverage")
ctx.require_contains("README.md", "check_suite_reachability.sh", "README suite reachability gate")
ctx.require_absent("README.md", "policy_decision_suite.gd", "removed auto-selection regression workflow")
ctx.require_absent("README.md", "gojo_sukuna_batch_probe.gd", "removed batch simulation workflow")

ctx.require_contains("tests/README.md", "domain_case_runner.gd", "tests fixed domain case runner doc")
ctx.require_contains("tests/README.md", "formal_character_registry.json", "tests formal character registry doc")
ctx.require_contains("tests/README.md", "check_suite_reachability.sh", "tests suite reachability gate doc")
ctx.require_contains("tests/README.md", "required_suite_paths", "tests registry suite anchor doc")
ctx.require_contains("tests/README.md", "required_test_names", "tests registry test anchor doc")
ctx.require_contains("tests/replay_cases/domain_cases.md", "CASE=all godot --headless --path . --script tests/helpers/domain_case_runner.gd", "domain case runner command")
ctx.require_absent("tests/README.md", "policy_decision_suite.gd", "removed auto-selection suite doc")
ctx.require_absent("tests/README.md", "gojo_sukuna_batch_probe.gd", "removed batch simulation doc")
ctx.require_contains("tests/run_with_gate.sh", "check_suite_reachability.sh", "suite reachability gate wiring")

ctx.finish("surface wiring, regression anchors, and README/test docs are aligned")
