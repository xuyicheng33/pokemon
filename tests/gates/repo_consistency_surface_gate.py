from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


def gdunit_test_pattern(test_name: str) -> str:
    return rf"func\s+test_{re.escape(test_name)}\s*\("


ctx = GateContext()
BASELINE_MATCHUP_CATALOG_PATH = "config/sample_matchup_catalog.json"
FORMAL_MANIFEST_PATH = "config/formal_character_manifest.json"

src_count = ctx.gd_line_count("src")
test_count = ctx.gd_line_count("test")
tests_count = ctx.gd_line_count("tests")
total_count = src_count + test_count + tests_count
ctx.require_readme_count("src", r"`src/\*\*/\*\.gd`：`(\d+)` 行", src_count)
ctx.require_readme_count("test", r"`test/\*\*/\*\.gd`：`(\d+)` 行", test_count)
ctx.require_readme_count("tests", r"`tests/\*\*/\*\.gd`：`(\d+)` 行", tests_count)
ctx.require_readme_count("total", r"GDScript 合计：`(\d+)` 行", total_count)

ctx.require_not_exists("tests/run_all.gd", "legacy manual Godot test entry")
ctx.require_not_exists("tests/suites", "legacy register_tests suite tree")

ctx.require_contains("tests/run_gdunit.sh", "GdUnitCmdTool.gd", "gdUnit CLI runner wiring")
ctx.require_contains("tests/run_gdunit.sh", "GdUnitCopyLog.gd", "gdUnit report log copier")
ctx.require_contains("tests/run_gdunit.sh", 'REPORT_DIR="${REPORT_DIR:-reports/gdunit}"', "gdUnit report dir default")
ctx.require_contains("tests/run_gdunit.sh", 'TEST_PATH="${TEST_PATH:-res://test}"', "gdUnit test root default")
ctx.require_contains("tests/run_with_gate.sh", "bash tests/run_gdunit.sh", "gdUnit gate wiring")
ctx.require_contains("tests/run_with_gate.sh", "check_suite_reachability.sh", "suite reachability gate wiring")
ctx.require_contains("tests/run_with_gate.sh", "check_repo_consistency.sh", "repo consistency gate wiring")
ctx.require_contains("tests/run_with_gate.sh", "check_sandbox_smoke_matrix.sh", "sandbox smoke matrix gate wiring")
ctx.require_contains("tests/run_with_gate.sh", 'echo "GATE PASSED: gdUnit', "gdUnit gate success wording")
ctx.require_contains("tests/support/formal_character_registry.gd", 'const REGISTRY_PATH := "res://config/formal_character_manifest.json"', "formal character manifest path")
ctx.require_absent("tests/support/formal_character_registry.gd", "build_suite_instances(", "legacy suite instance expansion")

ctx.require_contains_any(
    [
        "test/suites/content_logging_suite.gd",
        "test/suites/log_cause_semantics_suite.gd",
        "test/suites/log_cause_anchor_suite.gd",
    ],
    "direct damage cause_event_id should point to the real action:hit event",
    "direct damage real cause_event_id regression",
)
ctx.require_contains_any(
    [
        "test/suites/content_logging_suite.gd",
        "test/suites/log_cause_semantics_suite.gd",
        "test/suites/log_cause_anchor_suite.gd",
    ],
    "effect event cause_event_id must not point to itself",
    "self-referential cause_event_id regression",
)
ctx.require_contains_any(
    [
        "test/suites/content_logging_suite.gd",
        "test/suites/log_cause_semantics_suite.gd",
        "test/suites/log_cause_anchor_suite.gd",
    ],
    "turn_start regen cause_event_id should point to the real system:turn_start anchor",
    "turn_start anchor cause_event_id regression",
)
ctx.require_contains_any(
    [
        "test/suites/content_logging_suite.gd",
        "test/suites/log_cause_semantics_suite.gd",
        "test/suites/log_cause_anchor_suite.gd",
    ],
    "field expire cause_event_id should point to the real system:turn_end anchor",
    "field expire anchor cause_event_id regression",
)

ctx.require_regex("test/suites/setup_loadout_suite.gd", gdunit_test_pattern("candidate_skill_pool_validation"), "candidate skill pool dedicated regression")
ctx.require_regex("test/suites/setup_loadout_suite.gd", gdunit_test_pattern("setup_loadout_override_validation"), "setup override dedicated regression")
ctx.require_regex("test/suites/setup_loadout_suite.gd", gdunit_test_pattern("runtime_regular_skill_loadout_contract"), "runtime loadout dedicated regression")
ctx.require_regex("test/suites/setup_loadout_suite.gd", gdunit_test_pattern("same_side_duplicate_unit_forbidden"), "same-side duplicate unit regression")
ctx.require_regex("test/suites/gojo_murasaki_suite.gd", gdunit_test_pattern("gojo_murasaki_double_mark_burst_contract"), "gojo burst regression")
ctx.require_regex_any(
    [
        "test/suites/gojo_domain_suite.gd",
        "test/suites/gojo_mugen_suite.gd",
        "test/suites/gojo_unlimited_void_suite.gd",
    ],
    gdunit_test_pattern("gojo_mugen_incoming_accuracy_contract"),
    "gojo mugen regression",
)
ctx.require_regex_any(
    [
        "test/suites/gojo_domain_suite.gd",
        "test/suites/gojo_unlimited_void_suite.gd",
    ],
    gdunit_test_pattern("gojo_unlimited_void_runtime_contract"),
    "gojo domain regression",
)
ctx.require_regex("test/suites/sukuna_domain_suite.gd", gdunit_test_pattern("sukuna_domain_expire_chain_path"), "sukuna domain expire regression")
ctx.require_regex("test/suites/sukuna_domain_suite.gd", gdunit_test_pattern("sukuna_domain_break_chain_path"), "sukuna domain break regression")
ctx.require_regex("test/suites/ultimate_points_contract_suite.gd", gdunit_test_pattern("ultimate_points_regular_skill_gain_contract"), "ultimate point gain regression")
ctx.require_regex_any(
    [
        "test/suites/domain_clash_contract_suite.gd",
        "test/suites/domain_clash_resolution_suite.gd",
        "test/suites/domain_clash_guard_suite.gd",
    ],
    gdunit_test_pattern("field_clash_tie_replay_contract"),
    "field clash replay regression",
)
ctx.require_regex("test/suites/content_index_split_suite.gd", gdunit_test_pattern("content_snapshot_recursive_contract"), "recursive snapshot contract regression")
ctx.require_regex("test/suites/sukuna_kamado_suite.gd", gdunit_test_pattern("sukuna_kamado_stack_cap_path"), "sukuna kamado cap regression")
ctx.require_regex("test/suites/sukuna_kamado_suite.gd", gdunit_test_pattern("sukuna_kamado_forced_replace_on_exit_path"), "sukuna forced replace kamado regression")
ctx.require_regex("test/suites/sukuna_domain_suite.gd", gdunit_test_pattern("sukuna_domain_break_on_faint_path"), "sukuna creator faint field break regression")

for rel_path in [
    "docs/design/domain_field_template.md",
    "tests/replay_cases/domain_cases.md",
    "tests/helpers/domain_case_runner.gd",
]:
    ctx.require_exists(rel_path, "shared character asset doc")

ctx.require_contains("README.md", "candidate_skill_ids", "README candidate skill pool contract")
ctx.require_contains("README.md", "regular_skill_loadout_overrides", "README setup override contract")
ctx.require_contains("README.md", "设计稿 + 调整记录 + 内容资源 + SampleFactory 接线 + 角色 suite", "README character delivery workflow")
ctx.require_contains("README.md", "config/formal_character_manifest.json", "README formal character manifest")
ctx.require_contains("README.md", "content/battle_formats / combat_types / units / skills / passive_items / effects / fields / passive_skills / samples", "README content snapshot path coverage")
ctx.require_contains("README.md", "check_suite_reachability.sh", "README suite reachability gate")
ctx.require_contains("README.md", "tests/run_gdunit.sh", "README gdUnit entry")
ctx.require_contains("README.md", "JUnit XML", "README gdUnit junit report wording")
ctx.require_contains("README.md", "HTML", "README gdUnit html report wording")
ctx.require_absent("README.md", "tests/run_all.gd", "removed legacy test entry doc")
ctx.require_absent("README.md", "policy_decision_suite.gd", "removed auto-selection regression workflow")
ctx.require_absent("README.md", "gojo_sukuna_batch_probe.gd", "removed batch simulation workflow")

for needle, label in [
    ("func _override_container_factory_for_test", "manager test-only hook"),
    ("func _replace_public_snapshot_builder_for_test", "manager test-only hook"),
    ("func _inject_session_for_test", "manager test-only hook"),
    ("func _debug_session", "manager test-only hook"),
    ("func _shared_content_snapshot_cache_for_test", "manager test-only hook"),
]:
    ctx.require_absent("src/battle_core/facades/battle_core_manager.gd", needle, label)

for rel_path in [
    "test/suites/gojo_manager_smoke_suite.gd",
    "test/suites/sukuna_manager_smoke_suite.gd",
    "test/suites/content_snapshot_cache_suite.gd",
    "test/suites/manager_facade_internal_contract_suite.gd",
    "test/suites/manager_log_and_runtime_contract_suite.gd",
]:
    for needle, label in [
        ("_debug_session", "manager internal debug access"),
        ("_override_container_factory_for_test", "manager internal factory override"),
        ("_replace_public_snapshot_builder_for_test", "manager internal snapshot override"),
        ("_inject_session_for_test", "manager internal session injection"),
        ("_shared_content_snapshot_cache_for_test", "manager internal cache access"),
    ]:
        ctx.require_absent(rel_path, needle, label)

ctx.require_contains("tests/README.md", "domain_case_runner.gd", "tests fixed domain case runner doc")
ctx.require_contains("tests/README.md", "formal_character_manifest.json", "tests formal character manifest doc")
ctx.require_contains("tests/README.md", "check_suite_reachability.sh", "tests suite reachability gate doc")
ctx.require_contains("tests/README.md", "architecture_wiring_graph_gate.py", "tests wiring DAG gate doc")
ctx.require_contains("tests/README.md", "required_suite_paths", "tests registry suite anchor doc")
ctx.require_contains("tests/README.md", "required_test_names", "tests registry test anchor doc")
ctx.require_contains("tests/README.md", "tests/run_gdunit.sh", "tests gdUnit entry doc")
ctx.require_contains("tests/README.md", "gdUnit4", "tests gdUnit wording")
ctx.require_contains("tests/README.md", "test/suites", "tests gdUnit suite tree doc")
ctx.require_absent("tests/README.md", "run_all.gd", "removed legacy tests README entry")
ctx.require_absent("tests/README.md", "policy_decision_suite.gd", "removed auto-selection suite doc")
ctx.require_absent("tests/README.md", "gojo_sukuna_batch_probe.gd", "removed batch simulation doc")
ctx.require_contains("tests/replay_cases/domain_cases.md", "CASE=all godot --headless --path . --script tests/helpers/domain_case_runner.gd", "domain case runner command")
ctx.require_contains("tests/check_architecture_constraints.sh", "architecture_wiring_graph_gate.py", "runtime wiring DAG gate wiring")

baseline_matchup_catalog = ctx.load_json_object(BASELINE_MATCHUP_CATALOG_PATH, "baseline matchup catalog")
formal_manifest = ctx.load_json_object(FORMAL_MANIFEST_PATH, "formal character manifest")
baseline_matchups = baseline_matchup_catalog.get("matchups", {})
formal_matchups = formal_manifest.get("matchups", {})
if isinstance(baseline_matchups, dict) and isinstance(formal_matchups, dict):
    overlap = sorted(
        matchup_id
        for matchup_id in {str(raw_id).strip() for raw_id in baseline_matchups.keys()}
        if matchup_id and matchup_id in {str(raw_id).strip() for raw_id in formal_matchups.keys()}
    )
    if overlap:
        ctx.failures.append(
            "baseline/formal matchup catalog must not share matchup_id because SampleBattleFactory baseline lookup wins first: "
            + ", ".join(overlap)
        )

ctx.finish("gdUnit surface wiring, regression anchors, and README/test docs are aligned")
