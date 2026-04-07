from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext
from repo_consistency_formal_character_gate_pairs import validate_pair_catalog
from repo_consistency_formal_character_gate_support import (
    collect_scope_tree,
    collect_suite_refs,
    contract_field_list,
    scan_legacy_registry_refs,
    scan_legacy_sample_factory_calls,
    scan_pair_interaction_support_regressions,
    validate_required_contract_fields,
    validator_test_prefix,
)


ctx = GateContext()
MANIFEST_PATH = "config/formal_character_manifest.json"
FORMAL_REGISTRY_CONTRACTS_PATH = "config/formal_registry_contracts.json"
LEGACY_REGISTRY_PATH = "config/formal_character_registry.json"
LEGACY_RUNTIME_REGISTRY_PATH = "config/formal_character_runtime_registry.json"
LEGACY_DELIVERY_REGISTRY_PATH = "config/formal_character_delivery_registry.json"
LEGACY_MATCHUP_CATALOG_PATH = "config/formal_matchup_catalog.json"
VALIDATOR_BAD_CASE_SUITE_PATH = "tests/suites/extension_validation_contract_suite.gd"
PAIR_INTERACTION_SUITE_PATH = "tests/suites/formal_character_pair_smoke/interaction_suite.gd"
PAIR_INTERACTION_SUPPORT_PATH = "tests/suites/formal_character_pair_smoke/interaction_support.gd"
PAIR_INTERACTION_SCENARIO_REGISTRY_PATH = "tests/support/formal_pair_interaction/scenario_registry.gd"
FORMAL_ACCESS_SCRIPT_PATH = "src/composition/sample_battle_factory_formal_access.gd"
RUNTIME_REGISTRY_LOADER_PATH = "src/composition/sample_battle_factory_runtime_registry_loader.gd"
DELIVERY_REGISTRY_LOADER_PATH = "src/composition/sample_battle_factory_delivery_registry_loader.gd"
DELIVERY_REGISTRY_HELPER_PATH = "tests/support/formal_character_registry.gd"
RUNTIME_REGISTRY_HELPER_PATH = "src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd"
FORMAL_REGISTRY_CONTRACTS_SCRIPT_PATH = "src/shared/formal_registry_contracts.gd"
FORMAL_MANIFEST_SCRIPT_PATH = "src/shared/formal_character_manifest.gd"
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

manifest = ctx.load_json_object(MANIFEST_PATH, "formal character manifest")
formal_registry_contracts = ctx.load_json_object(FORMAL_REGISTRY_CONTRACTS_PATH, "formal registry contracts")
characters = manifest.get("characters", [])
matchups = manifest.get("matchups", {})
pair_interaction_cases = manifest.get("pair_interaction_cases", [])
character_runtime_contract_bucket = formal_registry_contracts.get("manifest_character_runtime", {})
character_delivery_contract_bucket = formal_registry_contracts.get("manifest_character_delivery", {})
pair_case_contract_bucket = formal_registry_contracts.get("pair_interaction_case", {})
character_runtime_required_string_fields = contract_field_list(
    ctx,
    character_runtime_contract_bucket,
    "required_string_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.manifest_character_runtime.required_string_fields",
)
character_runtime_required_array_fields = contract_field_list(
    ctx,
    character_runtime_contract_bucket,
    "required_array_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.manifest_character_runtime.required_array_fields",
)
contract_field_list(
    ctx,
    character_runtime_contract_bucket,
    "optional_string_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.manifest_character_runtime.optional_string_fields",
    required=False,
)
character_delivery_required_string_fields = contract_field_list(
    ctx,
    character_delivery_contract_bucket,
    "required_string_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.manifest_character_delivery.required_string_fields",
)
character_delivery_required_array_fields = contract_field_list(
    ctx,
    character_delivery_contract_bucket,
    "required_array_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.manifest_character_delivery.required_array_fields",
)
contract_field_list(
    ctx,
    character_delivery_contract_bucket,
    "optional_string_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.manifest_character_delivery.optional_string_fields",
    required=False,
)
pair_case_required_string_fields = contract_field_list(
    ctx,
    pair_case_contract_bucket,
    "required_string_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.pair_interaction_case.required_string_fields",
)
pair_case_required_array_fields = contract_field_list(
    ctx,
    pair_case_contract_bucket,
    "required_array_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.pair_interaction_case.required_array_fields",
)
contract_field_list(
    ctx,
    pair_case_contract_bucket,
    "optional_string_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.pair_interaction_case.optional_string_fields",
    required=False,
)

for legacy_path in [
    LEGACY_REGISTRY_PATH,
    LEGACY_RUNTIME_REGISTRY_PATH,
    LEGACY_DELIVERY_REGISTRY_PATH,
    LEGACY_MATCHUP_CATALOG_PATH,
]:
    if (ctx.root / legacy_path).exists():
        ctx.failures.append(f"{legacy_path} must be removed after manifest cutover")

if not isinstance(characters, list):
    ctx.failures.append(f"{MANIFEST_PATH} missing characters array")
    characters = []
if not characters:
    ctx.failures.append(f"{MANIFEST_PATH} must list at least one formal character")
if not isinstance(matchups, dict):
    ctx.failures.append(f"{MANIFEST_PATH} missing matchups dictionary")
    matchups = {}
if "pair_surface_cases" in manifest:
    ctx.failures.append(f"{MANIFEST_PATH} must not define pair_surface_cases; surface coverage is generated from matchups + characters.surface_smoke_skill_id")
if not isinstance(pair_interaction_cases, list):
    ctx.failures.append(f"{MANIFEST_PATH} pair_interaction_cases must be an array")
    pair_interaction_cases = []

runtime_registry_text = ctx.read_text(RUNTIME_REGISTRY_HELPER_PATH)
if f'REGISTRY_PATH := "res://{MANIFEST_PATH}"' not in runtime_registry_text:
    ctx.failures.append(f"runtime formal character loader must read {MANIFEST_PATH} directly")
runtime_registry_loader_text = ctx.read_text(RUNTIME_REGISTRY_LOADER_PATH)
if f'preload("res://{FORMAL_MANIFEST_SCRIPT_PATH}")' not in runtime_registry_loader_text:
    ctx.failures.append(f"{RUNTIME_REGISTRY_LOADER_PATH} must preload {FORMAL_MANIFEST_SCRIPT_PATH}")
if "build_runtime_entries_result" not in runtime_registry_loader_text:
    ctx.failures.append(f"{RUNTIME_REGISTRY_LOADER_PATH} must derive runtime entries from manifest")
delivery_registry_loader_text = ctx.read_text(DELIVERY_REGISTRY_LOADER_PATH)
if f'preload("res://{FORMAL_MANIFEST_SCRIPT_PATH}")' not in delivery_registry_loader_text:
    ctx.failures.append(f"{DELIVERY_REGISTRY_LOADER_PATH} must preload {FORMAL_MANIFEST_SCRIPT_PATH}")
if "build_delivery_entries_result" not in delivery_registry_loader_text:
    ctx.failures.append(f"{DELIVERY_REGISTRY_LOADER_PATH} must derive delivery entries from manifest")
delivery_registry_helper_text = ctx.read_text(DELIVERY_REGISTRY_HELPER_PATH)
if f'const REGISTRY_PATH := "res://{MANIFEST_PATH}"' not in delivery_registry_helper_text:
    ctx.failures.append(f"{DELIVERY_REGISTRY_HELPER_PATH} must read {MANIFEST_PATH} directly")

sample_factory_text = ctx.read_text("src/composition/sample_battle_factory.gd")
formal_access_text = ctx.read_text(FORMAL_ACCESS_SCRIPT_PATH)
if 'preload("res://%s"' % FORMAL_ACCESS_SCRIPT_PATH not in sample_factory_text:
    ctx.failures.append(f"SampleBattleFactory must delegate formal setup orchestration via {FORMAL_ACCESS_SCRIPT_PATH}")
if 'entry.get("formal_setup_matchup_id"' not in formal_access_text:
    ctx.failures.append("SampleBattleFactory formal setup helper must read formal_setup_matchup_id from manifest-derived runtime entry")
if "func configure_formal_manifest_path_override(" not in sample_factory_text:
    ctx.failures.append("SampleBattleFactory must expose configure_formal_manifest_path_override for manifest-based test overrides")
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

for rel_path in [RUNTIME_REGISTRY_HELPER_PATH, RUNTIME_REGISTRY_LOADER_PATH, DELIVERY_REGISTRY_LOADER_PATH, DELIVERY_REGISTRY_HELPER_PATH, "tests/check_suite_reachability.sh"]:
    ctx.require_absent(rel_path, LEGACY_REGISTRY_PATH, "legacy single formal registry path")
for legacy_path in [LEGACY_RUNTIME_REGISTRY_PATH, LEGACY_DELIVERY_REGISTRY_PATH, LEGACY_MATCHUP_CATALOG_PATH]:
    for rel_path in [RUNTIME_REGISTRY_HELPER_PATH, RUNTIME_REGISTRY_LOADER_PATH, DELIVERY_REGISTRY_LOADER_PATH, DELIVERY_REGISTRY_HELPER_PATH, "tests/check_suite_reachability.sh"]:
        ctx.require_absent(rel_path, legacy_path, "legacy split formal config path")
    for failure in scan_legacy_registry_refs(ctx, legacy_path):
        ctx.failures.append(failure)
for failure in scan_legacy_sample_factory_calls(ctx):
    ctx.failures.append(failure)
for failure in scan_legacy_registry_refs(ctx, LEGACY_REGISTRY_PATH):
    ctx.failures.append(failure)
for failure in scan_pair_interaction_support_regressions(ctx):
    ctx.failures.append(failure)

character_to_unit: dict[str, str] = {}
runtime_character_ids: list[str] = []
seen_characters: set[str] = set()
seen_units: set[str] = set()
reachable_suite_paths: set[str] = set()
pending_suite_paths: list[str] = collect_suite_refs(ctx.read_text("tests/run_all.gd"))
shared_suite_scope_paths = collect_scope_tree(ctx, SHARED_SUITE_ROOTS)

for entry in characters:
    character_id = str(entry.get("character_id", "")).strip()
    display_name = str(entry.get("display_name", "")).strip()
    unit_definition_id = str(entry.get("unit_definition_id", "")).strip()
    formal_setup_matchup_id = str(entry.get("formal_setup_matchup_id", "")).strip()
    required_content_paths = entry.get("required_content_paths", [])
    validator_script_path = str(entry.get("content_validator_script_path", "")).strip()
    design_doc = str(entry.get("design_doc", "")).strip()
    adjustment_doc = str(entry.get("adjustment_doc", "")).strip()
    surface_smoke_skill_id = str(entry.get("surface_smoke_skill_id", "")).strip()
    suite_path = str(entry.get("suite_path", "")).strip()
    required_suite_paths = entry.get("required_suite_paths", [])
    required_test_names = entry.get("required_test_names", [])
    design_needles = entry.get("design_needles", [])
    adjustment_needles = entry.get("adjustment_needles", [])
    validate_required_contract_fields(
        ctx,
        entry,
        character_runtime_required_string_fields,
        character_runtime_required_array_fields,
        "formal manifest runtime entry" if not character_id else f"formal manifest[{character_id}] runtime view",
    )
    validate_required_contract_fields(
        ctx,
        entry,
        character_delivery_required_string_fields,
        character_delivery_required_array_fields,
        "formal manifest delivery entry" if not character_id else f"formal manifest[{character_id}] delivery view",
    )
    if not character_id:
        ctx.failures.append("formal manifest character entry missing character_id")
        continue
    if character_id in seen_characters:
        ctx.failures.append(f"formal manifest duplicated character_id: {character_id}")
    seen_characters.add(character_id)
    runtime_character_ids.append(character_id)
    if not display_name:
        ctx.failures.append(f"formal manifest[{character_id}] missing display_name")
    if not unit_definition_id:
        ctx.failures.append(f"formal manifest[{character_id}] missing unit_definition_id")
    elif unit_definition_id in seen_units:
        ctx.failures.append(f"formal manifest duplicated unit_definition_id: {unit_definition_id}")
    seen_units.add(unit_definition_id)
    character_to_unit[character_id] = unit_definition_id
    if not formal_setup_matchup_id:
        ctx.failures.append(f"formal manifest[{character_id}] missing formal_setup_matchup_id")
    else:
        matchup_spec = matchups.get(formal_setup_matchup_id, {})
        if not isinstance(matchup_spec, dict) or not matchup_spec:
            ctx.failures.append(f"formal manifest[{character_id}] formal_setup_matchup_id missing from {MANIFEST_PATH}: {formal_setup_matchup_id}")
        else:
            p1_units = matchup_spec.get("p1_units", [])
            if not isinstance(p1_units, list) or not p1_units:
                ctx.failures.append(f"formal manifest[{character_id}] formal_setup_matchup_id must define non-empty p1_units: {formal_setup_matchup_id}")
            elif unit_definition_id and str(p1_units[0]).strip() != unit_definition_id:
                ctx.failures.append(
                    f"formal manifest[{character_id}] formal_setup_matchup_id must open with its own unit_definition_id: {formal_setup_matchup_id}"
                )
    if not isinstance(required_content_paths, list) or not required_content_paths:
        ctx.failures.append(f"formal manifest[{character_id}] missing required_content_paths")
    else:
        for rel_path in required_content_paths:
            ctx.require_exists(str(rel_path), f"{character_id} runtime content asset")
    if validator_script_path:
        ctx.require_exists(validator_script_path, f"{character_id} content validator script")
    if not design_doc:
        ctx.failures.append(f"formal manifest[{character_id}] missing design_doc")
    else:
        ctx.require_exists(design_doc, f"{character_id} design doc")
    if not adjustment_doc:
        ctx.failures.append(f"formal manifest[{character_id}] missing adjustment_doc")
    else:
        ctx.require_exists(adjustment_doc, f"{character_id} adjustment doc")
    if not surface_smoke_skill_id:
        ctx.failures.append(f"formal manifest[{character_id}] missing surface_smoke_skill_id")
    if not suite_path:
        ctx.failures.append(f"formal manifest[{character_id}] missing suite_path")
        suite_scope_paths: list[str] = []
    else:
        ctx.require_exists(suite_path, f"{character_id} suite")
        pending_suite_paths.append(suite_path)
        suite_scope_paths = [suite_path]
    if not isinstance(required_suite_paths, list) or not required_suite_paths:
        ctx.failures.append(f"formal manifest[{character_id}] missing required_suite_paths")
    else:
        for rel_path in required_suite_paths:
            rel_path = str(rel_path)
            ctx.require_exists(rel_path, f"{character_id} required suite")
            suite_scope_paths.append(rel_path)
    if not isinstance(required_test_names, list) or not required_test_names:
        ctx.failures.append(f"formal manifest[{character_id}] missing required_test_names")
    if not isinstance(design_needles, list) or not design_needles:
        ctx.failures.append(f"formal manifest[{character_id}] missing design_needles")
    if not isinstance(adjustment_needles, list) or not adjustment_needles:
        ctx.failures.append(f"formal manifest[{character_id}] missing adjustment_needles")
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
                f"formal manifest[{character_id}] must not duplicate shared regression anchor in required_test_names: {test_name}"
            )
    if validator_script_path:
        if VALIDATOR_BAD_CASE_SUITE_PATH not in required_suite_paths:
            ctx.failures.append(
                f"formal manifest[{character_id}] validator-backed character must include {VALIDATOR_BAD_CASE_SUITE_PATH} in required_suite_paths"
            )
        validator_prefix = validator_test_prefix(validator_script_path)
        if validator_prefix and not any(
            str(test_name).startswith(f"formal_{validator_prefix}_validator_") and "bad_case_contract" in str(test_name)
            for test_name in required_test_names if isinstance(required_test_names, list)
        ):
            ctx.failures.append(
                f"formal manifest[{character_id}] validator-backed character must include formal_{validator_prefix}_validator_*bad_case_contract regression anchors"
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

for entry in characters:
    character_id = str(entry.get("character_id", "")).strip()
    for rel_path in entry.get("required_suite_paths", []):
        rel_path = str(rel_path)
        if rel_path and rel_path not in reachable_suite_paths:
            ctx.failures.append(
                f"formal manifest[{character_id}] required_suite_path is not reachable from tests/run_all.gd wrapper tree: {rel_path}"
            )

for case_index, case_spec in enumerate(pair_interaction_cases):
    if not isinstance(case_spec, dict):
        ctx.failures.append(f"{MANIFEST_PATH} pair_interaction_cases[{case_index}] must be object")
        continue
    validate_required_contract_fields(
        ctx,
        case_spec,
        pair_case_required_string_fields,
        pair_case_required_array_fields,
        f"{MANIFEST_PATH} pair_interaction_cases[{case_index}]",
    )

validate_pair_catalog(
    ctx,
    runtime_character_ids=runtime_character_ids,
    delivery_registry=characters,
    character_to_unit=character_to_unit,
    matchups=matchups,
    pair_interaction_cases=pair_interaction_cases,
    matchup_catalog_path=MANIFEST_PATH,
    delivery_registry_path=MANIFEST_PATH,
    scenario_registry_path=PAIR_INTERACTION_SCENARIO_REGISTRY_PATH,
)

ctx.finish("formal character manifest, pair coverage, and anti-regression guards are aligned")
