from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext
from repo_consistency_formal_character_gate_characters import validate_character_entries
from repo_consistency_formal_character_gate_capabilities import validate_capability_catalog
from repo_consistency_formal_character_gate_cutover import validate_manifest_cutover
from repo_consistency_formal_character_gate_pairs import validate_pair_catalog
from repo_consistency_formal_character_gate_support import (
    contract_field_list,
    load_delivery_registry_entries,
    validate_required_contract_fields,
)


ctx = GateContext()
MANIFEST_PATH = "config/formal_character_manifest.json"
FORMAL_REGISTRY_CONTRACTS_PATH = "config/formal_registry_contracts.json"
CAPABILITY_CATALOG_PATH = "config/formal_character_capability_catalog.json"
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
DELIVERY_REGISTRY_EXPORT_SCRIPT_PATH = "tests/helpers/export_formal_delivery_registry.gd"
CAPABILITY_FACTS_EXPORT_SCRIPT_PATH = "tests/helpers/export_formal_capability_facts.gd"
RUNTIME_REGISTRY_HELPER_PATH = "src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd"
FORMAL_REGISTRY_CONTRACTS_SCRIPT_PATH = "src/shared/formal_registry_contracts.gd"
FORMAL_MANIFEST_SCRIPT_PATH = "src/shared/formal_character_manifest.gd"
FORMAL_BASELINES_PATH = "src/shared/formal_character_baselines.gd"
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
pair_case_required_positive_int_fields = contract_field_list(
    ctx,
    pair_case_contract_bucket,
    "required_positive_int_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.pair_interaction_case.required_positive_int_fields",
)
contract_field_list(
    ctx,
    pair_case_contract_bucket,
    "optional_string_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.pair_interaction_case.optional_string_fields",
    required=False,
)

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

delivery_registry = load_delivery_registry_entries(
    ctx,
    export_script_path=DELIVERY_REGISTRY_EXPORT_SCRIPT_PATH,
    manifest_path=MANIFEST_PATH,
)
delivery_entries_by_character = {
    str(entry.get("character_id", "")).strip(): entry
    for entry in delivery_registry
    if isinstance(entry, dict) and str(entry.get("character_id", "")).strip()
}

validate_manifest_cutover(
    ctx,
    manifest_path=MANIFEST_PATH,
    legacy_registry_path=LEGACY_REGISTRY_PATH,
    legacy_runtime_registry_path=LEGACY_RUNTIME_REGISTRY_PATH,
    legacy_delivery_registry_path=LEGACY_DELIVERY_REGISTRY_PATH,
    legacy_matchup_catalog_path=LEGACY_MATCHUP_CATALOG_PATH,
    runtime_registry_helper_path=RUNTIME_REGISTRY_HELPER_PATH,
    runtime_registry_loader_path=RUNTIME_REGISTRY_LOADER_PATH,
    delivery_registry_loader_path=DELIVERY_REGISTRY_LOADER_PATH,
    delivery_registry_helper_path=DELIVERY_REGISTRY_HELPER_PATH,
    formal_manifest_script_path=FORMAL_MANIFEST_SCRIPT_PATH,
    formal_access_script_path=FORMAL_ACCESS_SCRIPT_PATH,
    pair_interaction_suite_path=PAIR_INTERACTION_SUITE_PATH,
    pair_interaction_support_path=PAIR_INTERACTION_SUPPORT_PATH,
)

character_validation = validate_character_entries(
    ctx,
    manifest_path=MANIFEST_PATH,
    baseline_registry_path=FORMAL_BASELINES_PATH,
    characters=characters,
    delivery_entries_by_character=delivery_entries_by_character,
    matchups=matchups,
    character_runtime_required_string_fields=character_runtime_required_string_fields,
    character_runtime_required_array_fields=character_runtime_required_array_fields,
    character_delivery_required_string_fields=character_delivery_required_string_fields,
    character_delivery_required_array_fields=character_delivery_required_array_fields,
    validator_bad_case_suite_path=VALIDATOR_BAD_CASE_SUITE_PATH,
    shared_suite_roots=SHARED_SUITE_ROOTS,
)

validate_capability_catalog(
    ctx,
    capability_catalog_path=CAPABILITY_CATALOG_PATH,
    characters=characters,
    manifest_path=MANIFEST_PATH,
    export_script_path=CAPABILITY_FACTS_EXPORT_SCRIPT_PATH,
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
        pair_case_required_positive_int_fields,
    )

validate_pair_catalog(
    ctx,
    runtime_character_ids=character_validation["runtime_character_ids"],
    delivery_registry=delivery_registry,
    character_to_unit=character_validation["character_to_unit"],
    matchups=matchups,
    pair_interaction_cases=pair_interaction_cases,
    matchup_catalog_path=MANIFEST_PATH,
    delivery_registry_path=MANIFEST_PATH,
    scenario_registry_path=PAIR_INTERACTION_SCENARIO_REGISTRY_PATH,
)

ctx.finish("formal character manifest, pair coverage, and anti-regression guards are aligned")
