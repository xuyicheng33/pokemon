from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext
from repo_consistency_formal_character_gate_support import (
    collect_scope_tree,
    collect_suite_refs,
    scan_legacy_registry_refs,
    scan_legacy_sample_factory_calls,
    scan_pair_interaction_support_regressions,
    validator_test_prefix,
)


ctx = GateContext()
RUNTIME_REGISTRY_PATH = "config/formal_character_runtime_registry.json"
DELIVERY_REGISTRY_PATH = "config/formal_character_delivery_registry.json"
LEGACY_REGISTRY_PATH = "config/formal_character_registry.json"
MATCHUP_CATALOG_PATH = "config/formal_matchup_catalog.json"
VALIDATOR_BAD_CASE_SUITE_PATH = "tests/suites/extension_validation_contract_suite.gd"
PAIR_SMOKE_SUITE_PATH = "tests/suites/formal_character_pair_smoke_suite.gd"
PAIR_INTERACTION_SUITE_PATH = "tests/suites/formal_character_pair_smoke/interaction_suite.gd"
PAIR_INTERACTION_SUPPORT_PATH = "tests/suites/formal_character_pair_smoke/interaction_support.gd"
DELIVERY_REGISTRY_HELPER_PATH = "tests/support/formal_character_registry.gd"
RUNTIME_REGISTRY_HELPER_PATH = "src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd"
SHARED_SUITE_ROOTS = [
    "tests/suites/formal_character_pair_smoke_suite.gd",
    "tests/suites/ultimate_points_contract_suite.gd",
    "tests/suites/domain_clash_resolution_suite.gd",
    "tests/suites/domain_clash_guard_suite.gd",
    "tests/suites/field_lifecycle_contract_suite.gd",
    "tests/suites/ultimate_field_suite.gd",
    "tests/suites/heal_extension_suite.gd",
    "tests/suites/skill_execute_contract_suite.gd",
    "tests/suites/multihit_skill_runtime_suite.gd",
    "tests/suites/persistent_stat_stage_suite.gd",
    "tests/suites/combat_type_definition_suite.gd",
    "tests/suites/combat_type_runtime_suite.gd",
]

runtime_registry = ctx.load_json_array(RUNTIME_REGISTRY_PATH, "formal character runtime registry")
delivery_registry = ctx.load_json_array(DELIVERY_REGISTRY_PATH, "formal character delivery registry")
matchup_catalog = ctx.load_json_object(MATCHUP_CATALOG_PATH, "formal matchup catalog")
matchups = matchup_catalog.get("matchups", {})
pair_surface_cases = matchup_catalog.get("pair_surface_cases", [])
pair_interaction_cases = matchup_catalog.get("pair_interaction_cases", [])

if (ctx.root / LEGACY_REGISTRY_PATH).exists():
    ctx.failures.append(f"{LEGACY_REGISTRY_PATH} must be removed after runtime/delivery registry split")
if not runtime_registry:
    ctx.failures.append(f"{RUNTIME_REGISTRY_PATH} must list at least one formal runtime entry")
if not delivery_registry:
    ctx.failures.append(f"{DELIVERY_REGISTRY_PATH} must list at least one formal delivery entry")
if not isinstance(matchups, dict):
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} missing matchups dictionary")
    matchups = {}
if not isinstance(pair_surface_cases, list):
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases must be an array")
    pair_surface_cases = []
if not isinstance(pair_interaction_cases, list):
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases must be an array")
    pair_interaction_cases = []

runtime_registry_text = ctx.read_text(RUNTIME_REGISTRY_HELPER_PATH)
if f'REGISTRY_PATH := "res://{RUNTIME_REGISTRY_PATH}"' not in runtime_registry_text:
    ctx.failures.append(f"runtime formal character loader must read {RUNTIME_REGISTRY_PATH} directly")
for needle, label in [
    ('entry.get("formal_setup_matchup_id"', "formal_setup_matchup_id runtime field"),
    ('entry.get("required_content_paths"', "required_content_paths runtime field"),
    ('entry.get("content_validator_script_path"', "content validator runtime field"),
]:
    if needle not in runtime_registry_text:
        ctx.failures.append(f"runtime formal character loader must validate {label}")
for needle, label in [
    ("duplicated character_id", "duplicate runtime character_id guard"),
    ("duplicated unit_definition_id", "duplicate runtime unit_definition_id guard"),
    ("missing unit_definition_id", "runtime unit_definition_id guard"),
    ("missing formal_setup_matchup_id", "runtime formal_setup_matchup_id guard"),
    ("missing required_content_paths", "runtime required_content_paths guard"),
]:
    if needle not in runtime_registry_text:
        ctx.failures.append(f"runtime formal character loader missing {label}")

delivery_registry_text = ctx.read_text(DELIVERY_REGISTRY_HELPER_PATH)
if f'REGISTRY_PATH := "res://{DELIVERY_REGISTRY_PATH}"' not in delivery_registry_text:
    ctx.failures.append(f"delivery formal character loader must read {DELIVERY_REGISTRY_PATH} directly")
for needle in ["missing display_name", "missing design_doc", "missing adjustment_doc", "missing suite_path", "missing required_suite_paths", "missing required_test_names"]:
    if needle not in delivery_registry_text:
        ctx.failures.append(f"delivery formal character loader must validate {needle}")

sample_factory_text = ctx.read_text("src/composition/sample_battle_factory.gd")
if 'entry.get("formal_setup_matchup_id"' not in sample_factory_text:
    ctx.failures.append("SampleBattleFactory.build_formal_character_setup_result must read formal_setup_matchup_id from runtime registry")
for legacy_wrapper in [
    "func build_setup_from_side_specs(",
    "func content_snapshot_paths(",
    "func content_snapshot_paths_for_setup(",
    "func collect_tres_paths(",
    "func collect_tres_paths_recursive(",
    "func build_setup_by_matchup_id(",
    "func formal_character_ids(",
    "func formal_unit_definition_ids(",
    "func build_formal_character_setup(",
    "func build_sample_setup(",
    "func build_demo_replay_input(",
    "func build_passive_item_demo_replay_input(",
]:
    if legacy_wrapper in sample_factory_text:
        ctx.failures.append(f"SampleBattleFactory still exposes removed legacy wrapper: {legacy_wrapper}")

pair_interaction_text = ctx.read_text(PAIR_INTERACTION_SUITE_PATH)
if f'preload("res://{PAIR_INTERACTION_SUPPORT_PATH}")' not in pair_interaction_text:
    ctx.failures.append("formal pair interaction wrapper must preload tests/suites/formal_character_pair_smoke/interaction_support.gd")
for stale_needle, label in [
    ("EXPECTED_SCENARIO_IDS", "local scenario list"),
    ("match scenario_id", "local scenario dispatch"),
    ("._test_", "cross-suite private _test_* call"),
]:
    if stale_needle in pair_interaction_text:
        ctx.failures.append(f"{PAIR_INTERACTION_SUITE_PATH} must not keep stale {label}")

pair_interaction_support_text = ctx.read_text(PAIR_INTERACTION_SUPPORT_PATH)
if 'preload("res://tests/suites/' in pair_interaction_support_text:
    ctx.failures.append(f"{PAIR_INTERACTION_SUPPORT_PATH} must not preload suite files directly")
if "._test_" in pair_interaction_support_text:
    ctx.failures.append(f"{PAIR_INTERACTION_SUPPORT_PATH} must not call suite private _test_* helpers")

for rel_path in [RUNTIME_REGISTRY_HELPER_PATH, DELIVERY_REGISTRY_HELPER_PATH, "tests/check_suite_reachability.sh"]:
    ctx.require_absent(rel_path, LEGACY_REGISTRY_PATH, "legacy single formal registry path")
for failure in scan_legacy_sample_factory_calls(ctx):
    ctx.failures.append(failure)
for failure in scan_legacy_registry_refs(ctx, LEGACY_REGISTRY_PATH):
    ctx.failures.append(failure)
for failure in scan_pair_interaction_support_regressions(ctx):
    ctx.failures.append(failure)

character_to_unit: dict[str, str] = {}
runtime_character_ids: list[str] = []
delivery_character_ids: list[str] = []
seen_runtime_characters: set[str] = set()
seen_runtime_units: set[str] = set()
seen_delivery_characters: set[str] = set()

for entry in runtime_registry:
    character_id = str(entry.get("character_id", "")).strip()
    unit_definition_id = str(entry.get("unit_definition_id", "")).strip()
    formal_setup_matchup_id = str(entry.get("formal_setup_matchup_id", "")).strip()
    required_content_paths = entry.get("required_content_paths", [])
    validator_script_path = str(entry.get("content_validator_script_path", "")).strip()
    if not character_id:
        ctx.failures.append("formal runtime registry entry missing character_id")
        continue
    if character_id in seen_runtime_characters:
        ctx.failures.append(f"formal runtime registry duplicated character_id: {character_id}")
    seen_runtime_characters.add(character_id)
    runtime_character_ids.append(character_id)
    if not unit_definition_id:
        ctx.failures.append(f"formal runtime registry[{character_id}] missing unit_definition_id")
    elif unit_definition_id in seen_runtime_units:
        ctx.failures.append(f"formal runtime registry duplicated unit_definition_id: {unit_definition_id}")
    seen_runtime_units.add(unit_definition_id)
    character_to_unit[character_id] = unit_definition_id
    if not formal_setup_matchup_id:
        ctx.failures.append(f"formal runtime registry[{character_id}] missing formal_setup_matchup_id")
    else:
        matchup_spec = matchups.get(formal_setup_matchup_id, {})
        if not isinstance(matchup_spec, dict) or not matchup_spec:
            ctx.failures.append(f"formal runtime registry[{character_id}] formal_setup_matchup_id missing from {MATCHUP_CATALOG_PATH}: {formal_setup_matchup_id}")
        else:
            p1_units = matchup_spec.get("p1_units", [])
            if not isinstance(p1_units, list) or not p1_units:
                ctx.failures.append(f"formal runtime registry[{character_id}] formal_setup_matchup_id must define non-empty p1_units: {formal_setup_matchup_id}")
            elif unit_definition_id and str(p1_units[0]).strip() != unit_definition_id:
                ctx.failures.append(
                    f"formal runtime registry[{character_id}] formal_setup_matchup_id must open with its own unit_definition_id: {formal_setup_matchup_id}"
                )
    if not isinstance(required_content_paths, list) or not required_content_paths:
        ctx.failures.append(f"formal runtime registry[{character_id}] missing required_content_paths")
    else:
        for rel_path in required_content_paths:
            ctx.require_exists(str(rel_path), f"{character_id} runtime content asset")
    if validator_script_path:
        ctx.require_exists(validator_script_path, f"{character_id} content validator script")

reachable_suite_paths: set[str] = set()
pending_suite_paths: list[str] = collect_suite_refs(ctx.read_text("tests/run_all.gd"))
shared_suite_scope_paths = collect_scope_tree(ctx, SHARED_SUITE_ROOTS)

for entry in delivery_registry:
    character_id = str(entry.get("character_id", "")).strip()
    display_name = str(entry.get("display_name", "")).strip()
    design_doc = str(entry.get("design_doc", "")).strip()
    adjustment_doc = str(entry.get("adjustment_doc", "")).strip()
    suite_path = str(entry.get("suite_path", "")).strip()
    required_suite_paths = entry.get("required_suite_paths", [])
    required_test_names = entry.get("required_test_names", [])
    design_needles = entry.get("design_needles", [])
    adjustment_needles = entry.get("adjustment_needles", [])
    if not character_id:
        ctx.failures.append("formal delivery registry entry missing character_id")
        continue
    if character_id in seen_delivery_characters:
        ctx.failures.append(f"formal delivery registry duplicated character_id: {character_id}")
    seen_delivery_characters.add(character_id)
    delivery_character_ids.append(character_id)
    if not display_name:
        ctx.failures.append(f"formal delivery registry[{character_id}] missing display_name")
    if not design_doc:
        ctx.failures.append(f"formal delivery registry[{character_id}] missing design_doc")
    else:
        ctx.require_exists(design_doc, f"{character_id} design doc")
    if not adjustment_doc:
        ctx.failures.append(f"formal delivery registry[{character_id}] missing adjustment_doc")
    else:
        ctx.require_exists(adjustment_doc, f"{character_id} adjustment doc")
    if not suite_path:
        ctx.failures.append(f"formal delivery registry[{character_id}] missing suite_path")
        suite_scope_paths: list[str] = []
    else:
        ctx.require_exists(suite_path, f"{character_id} suite")
        pending_suite_paths.append(suite_path)
        suite_scope_paths = [suite_path]
    if not isinstance(required_suite_paths, list) or not required_suite_paths:
        ctx.failures.append(f"formal delivery registry[{character_id}] missing required_suite_paths")
    else:
        for rel_path in required_suite_paths:
            rel_path = str(rel_path)
            ctx.require_exists(rel_path, f"{character_id} required suite")
            suite_scope_paths.append(rel_path)
    if not isinstance(required_test_names, list) or not required_test_names:
        ctx.failures.append(f"formal delivery registry[{character_id}] missing required_test_names")
    if not isinstance(design_needles, list) or not design_needles:
        ctx.failures.append(f"formal delivery registry[{character_id}] missing design_needles")
    if not isinstance(adjustment_needles, list) or not adjustment_needles:
        ctx.failures.append(f"formal delivery registry[{character_id}] missing adjustment_needles")
    if design_doc:
        for anchor_id in design_needles if isinstance(design_needles, list) else []:
            ctx.require_anchor(design_doc, str(anchor_id), f"{character_id} design anchor")
    if adjustment_doc:
        for anchor_id in adjustment_needles if isinstance(adjustment_needles, list) else []:
            ctx.require_anchor(adjustment_doc, str(anchor_id), f"{character_id} adjustment anchor")
    scoped_suite_paths = collect_scope_tree(ctx, suite_scope_paths)
    for test_name in required_test_names if isinstance(required_test_names, list) else []:
        ctx.require_contains_any(scoped_suite_paths, f'runner.run_test("{str(test_name)}"', f"{character_id} regression anchor")
        if any(f'runner.run_test("{str(test_name)}"' in ctx.read_text(shared_path) for shared_path in shared_suite_scope_paths):
            ctx.failures.append(
                f"formal delivery registry[{character_id}] must not duplicate shared regression anchor in required_test_names: {test_name}"
            )
    runtime_entry = next((candidate for candidate in runtime_registry if str(candidate.get("character_id", "")).strip() == character_id), None)
    validator_script_path = "" if runtime_entry is None else str(runtime_entry.get("content_validator_script_path", "")).strip()
    if validator_script_path:
        if VALIDATOR_BAD_CASE_SUITE_PATH not in required_suite_paths:
            ctx.failures.append(
                f"formal delivery registry[{character_id}] validator-backed character must include {VALIDATOR_BAD_CASE_SUITE_PATH} in required_suite_paths"
            )
        validator_prefix = validator_test_prefix(validator_script_path)
        if validator_prefix and not any(
            str(test_name).startswith(f"formal_{validator_prefix}_validator_") and "bad_case_contract" in str(test_name)
            for test_name in required_test_names if isinstance(required_test_names, list)
        ):
            ctx.failures.append(
                f"formal delivery registry[{character_id}] validator-backed character must include formal_{validator_prefix}_validator_*bad_case_contract regression anchors"
            )

while pending_suite_paths:
    suite_path = pending_suite_paths.pop()
    if suite_path in reachable_suite_paths:
        continue
    if not (ctx.root / suite_path).exists():
        continue
    reachable_suite_paths.add(suite_path)
    for child_suite in collect_suite_refs(ctx.read_text(suite_path)):
        pending_suite_paths.append(child_suite)

for entry in delivery_registry:
    character_id = str(entry.get("character_id", "")).strip()
    for rel_path in entry.get("required_suite_paths", []):
        rel_path = str(rel_path)
        if rel_path and rel_path not in reachable_suite_paths:
            ctx.failures.append(
                f"formal delivery registry[{character_id}] required_suite_path is not reachable from tests/run_all.gd wrapper tree: {rel_path}"
            )

if set(runtime_character_ids) != set(delivery_character_ids):
    ctx.failures.append(
        f"runtime/delivery formal registry character_id set mismatch: runtime={sorted(set(runtime_character_ids))} delivery={sorted(set(delivery_character_ids))}"
    )

expected_surface_pairs = {
    f"{left}->{right}"
    for left in runtime_character_ids
    for right in runtime_character_ids
    if left != right
}
actual_surface_pairs: set[str] = set()
for case_index, raw_case in enumerate(pair_surface_cases):
    if not isinstance(raw_case, dict):
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] must be object")
        continue
    matchup_id = str(raw_case.get("matchup_id", "")).strip()
    p1_character_id = str(raw_case.get("p1_character_id", "")).strip()
    p2_character_id = str(raw_case.get("p2_character_id", "")).strip()
    p1_unit_definition_id = str(raw_case.get("p1_unit_definition_id", "")).strip()
    p2_unit_definition_id = str(raw_case.get("p2_unit_definition_id", "")).strip()
    if matchup_id not in matchups:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] unknown matchup_id: {matchup_id}")
    if p1_character_id not in character_to_unit or p2_character_id not in character_to_unit:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] references unknown formal character id")
        continue
    if p1_character_id == p2_character_id:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] cannot target the same character twice")
        continue
    if p1_unit_definition_id != character_to_unit[p1_character_id]:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] p1_unit_definition_id drifted from runtime registry")
    if p2_unit_definition_id != character_to_unit[p2_character_id]:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] p2_unit_definition_id drifted from runtime registry")
    pair_key = f"{p1_character_id}->{p2_character_id}"
    if pair_key in actual_surface_pairs:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} duplicated directed pair_surface case: {pair_key}")
    actual_surface_pairs.add(pair_key)
missing_surface_pairs = sorted(expected_surface_pairs - actual_surface_pairs)
if missing_surface_pairs:
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} missing directed pair_surface coverage: {', '.join(missing_surface_pairs)}")
extra_surface_pairs = sorted(actual_surface_pairs - expected_surface_pairs)
if extra_surface_pairs:
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} contains non-matrix pair_surface coverage: {', '.join(extra_surface_pairs)}")

expected_interaction_pairs = {
    "<->".join(sorted([runtime_character_ids[left_index], runtime_character_ids[right_index]]))
    for left_index in range(len(runtime_character_ids))
    for right_index in range(left_index + 1, len(runtime_character_ids))
}
actual_interaction_pairs: set[str] = set()
for case_index, raw_case in enumerate(pair_interaction_cases):
    if not isinstance(raw_case, dict):
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases[{case_index}] must be object")
        continue
    scenario_id = str(raw_case.get("scenario_id", "")).strip()
    matchup_id = str(raw_case.get("matchup_id", "")).strip()
    character_ids = raw_case.get("character_ids", [])
    if not scenario_id:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases[{case_index}] missing scenario_id")
    if matchup_id not in matchups:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases[{case_index}] unknown matchup_id: {matchup_id}")
    if not isinstance(character_ids, list) or len(character_ids) != 2:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases[{case_index}] must define exactly two character_ids")
        continue
    left_character_id = str(character_ids[0]).strip()
    right_character_id = str(character_ids[1]).strip()
    if left_character_id not in character_to_unit or right_character_id not in character_to_unit:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases[{case_index}] references unknown formal character id")
        continue
    if left_character_id == right_character_id:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases[{case_index}] cannot target the same character twice")
        continue
    pair_key = "<->".join(sorted([left_character_id, right_character_id]))
    if pair_key in actual_interaction_pairs:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} duplicated unordered pair_interaction case: {pair_key}")
    actual_interaction_pairs.add(pair_key)
missing_interaction_pairs = sorted(expected_interaction_pairs - actual_interaction_pairs)
if missing_interaction_pairs:
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} missing unordered pair_interaction coverage: {', '.join(missing_interaction_pairs)}")
extra_interaction_pairs = sorted(actual_interaction_pairs - expected_interaction_pairs)
if extra_interaction_pairs:
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} contains non-matrix pair_interaction coverage: {', '.join(extra_interaction_pairs)}")

ctx.finish("runtime/delivery formal registry split, pair coverage, and anti-regression guards are aligned")
