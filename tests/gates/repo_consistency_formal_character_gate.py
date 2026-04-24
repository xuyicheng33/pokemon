from __future__ import annotations

import sys
import re
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext
from repo_consistency_formal_character_gate_characters import validate_character_entries
from repo_consistency_formal_character_gate_capabilities import validate_capability_catalog
from repo_consistency_formal_character_gate_cutover import validate_manifest_cutover
from repo_consistency_formal_character_gate_pairs import validate_pair_catalog
from repo_consistency_formal_character_manifest_io_support import (
    contract_field_list,
    load_delivery_registry_entries,
    load_generated_registry_views,
    load_pair_catalog,
    validate_generated_registry_views,
    validate_required_contract_fields,
)
from repo_consistency_formal_character_suite_needle_support import (
    validate_entry_validator_structure,
)


ctx = GateContext()
MANIFEST_PATH = "config/formal_character_manifest.json"
FORMAL_REGISTRY_CONTRACTS_PATH = "config/formal_registry_contracts.json"
CAPABILITY_CATALOG_PATH = "config/formal_character_capability_catalog.json"
FORMAL_CHARACTER_SOURCE_DIR = "config/formal_character_sources"
LEGACY_REGISTRY_PATH = "config/formal_character_registry.json"
LEGACY_RUNTIME_REGISTRY_PATH = "config/formal_character_runtime_registry.json"
LEGACY_DELIVERY_REGISTRY_PATH = "config/formal_character_delivery_registry.json"
LEGACY_MATCHUP_CATALOG_PATH = "config/formal_matchup_catalog.json"
VALIDATOR_BAD_CASE_SUITE_PATH = "test/suites/extension_validation_contract_suite.gd"
PAIR_INTERACTION_SUITE_PATH = "test/suites/formal_character_pair_smoke/interaction_suite.gd"
PAIR_INTERACTION_SUPPORT_PATH = "test/suites/formal_character_pair_smoke/interaction_support.gd"
PAIR_INTERACTION_SCENARIO_REGISTRY_PATH = "tests/support/formal_pair_interaction/scenario_registry.gd"
PAIR_INTERACTION_SCENARIO_EXPORT_SCRIPT_PATH = "tests/helpers/export_formal_pair_interaction_runner_keys.gd"
PAIR_INTERACTION_CASE_BUILDER_PATH = "src/shared/formal_character_manifest/formal_character_pair_interaction_case_builder.gd"
FORMAL_ACCESS_SCRIPT_PATH = "src/composition/sample_battle_factory_formal_access.gd"
RUNTIME_REGISTRY_LOADER_PATH = "src/composition/sample_battle_factory_formal_access.gd"
DELIVERY_REGISTRY_LOADER_PATH = "src/composition/sample_battle_factory_formal_access.gd"
DELIVERY_REGISTRY_HELPER_PATH = "tests/support/formal_character_registry.gd"
DELIVERY_REGISTRY_EXPORT_SCRIPT_PATH = "tests/helpers/export_formal_delivery_registry.gd"
CAPABILITY_FACTS_EXPORT_SCRIPT_PATH = "tests/helpers/export_formal_capability_facts.gd"
PAIR_CATALOG_EXPORT_SCRIPT_PATH = "tests/helpers/export_formal_pair_catalog.gd"
FORMAL_REGISTRY_VIEWS_EXPORT_SCRIPT_PATH = "tests/helpers/export_formal_registry_views.gd"
RUNTIME_REGISTRY_HELPER_PATH = "src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd"
FORMAL_REGISTRY_CONTRACTS_SCRIPT_PATH = "src/shared/formal_registry_contracts.gd"
FORMAL_MANIFEST_SCRIPT_PATH = "src/shared/formal_character_manifest.gd"
FORMAL_BASELINES_PATH = "src/shared/formal_character_baselines.gd"
SHARED_SUITE_ROOTS = [
    "test/suites/formal_character_pair_smoke_suite.gd",
    "test/suites/ultimate_points_contract_suite.gd",
    "test/suites/domain_clash_resolution_suite.gd",
    "test/suites/domain_clash_guard_suite.gd",
    "test/suites/field_lifecycle_contract_suite.gd",
    "test/suites/ultimate_field_suite.gd",
    "test/suites/heal_extension_suite.gd",
    "test/suites/skill_execute_contract_suite.gd",
    "test/suites/multihit_skill_runtime_suite.gd",
    "test/suites/persistent_stat_stage_suite.gd",
    "test/suites/combat_type_definition_suite.gd",
    "test/suites/combat_type_runtime_suite.gd",
]
LIVE_PLACEHOLDER_SCAN_ROOTS = [
    "config/formal_character_sources",
    "src/shared/formal_character_baselines",
    "src/battle_core/content/formal_validators",
    "test/suites",
    "tests/support/formal_pair_interaction",
]
LIVE_PLACEHOLDER_NEEDLES = [
    "FILL_IN",
    "TODO: implement",
    "interaction placeholder",
    "FORMAL_DRAFT_",
    "draft_marker",
]


def validate_no_live_scaffold_placeholders(ctx: GateContext) -> None:
    for scan_root in LIVE_PLACEHOLDER_SCAN_ROOTS:
        root_path = ctx.root / scan_root
        if not root_path.exists():
            continue
        for path in sorted(root_path.rglob("*")):
            if not path.is_file() or path.suffix not in {".gd", ".json"}:
                continue
            rel_path = str(path.relative_to(ctx.root))
            text = path.read_text(encoding="utf-8")
            for needle in LIVE_PLACEHOLDER_NEEDLES:
                if needle in text:
                    ctx.failures.append(f"{rel_path} contains live scaffold placeholder: {needle}")


def validate_no_incomplete_live_validators(ctx: GateContext, characters: list) -> None:
    for entry in characters:
        if not isinstance(entry, dict):
            continue
        character_id = str(entry.get("character_id", "")).strip()
        validator_script_path = str(entry.get("content_validator_script_path", "")).strip()
        if not validator_script_path:
            continue
        text = ctx.read_text(validator_script_path)
        if re.search(r"(?m)^\s*pass\s*$", text):
            ctx.failures.append(f"{validator_script_path} contains pass in live validator for {character_id}")


def validate_pair_interaction_ordering_contract(ctx: GateContext) -> None:
    builder_text = ctx.read_text(PAIR_INTERACTION_CASE_BUILDER_PATH)
    required_needles = [
        "expected_other_character_ids",
        "range(owner_index)",
        "must only target earlier manifest characters",
        "missing owned_pair_interaction_specs coverage for earlier characters",
    ]
    for needle in required_needles:
        if needle not in builder_text:
            ctx.failures.append(f"{PAIR_INTERACTION_CASE_BUILDER_PATH} must keep manifest-order pair ownership contract: {needle}")

manifest = ctx.load_json_object(MANIFEST_PATH, "formal character manifest")
capability_catalog = ctx.load_json_object(CAPABILITY_CATALOG_PATH, "formal character capability catalog")
formal_registry_contracts = ctx.load_json_object(FORMAL_REGISTRY_CONTRACTS_PATH, "formal registry contracts")
generated_registry_views = load_generated_registry_views(
    ctx,
    export_script_path=FORMAL_REGISTRY_VIEWS_EXPORT_SCRIPT_PATH,
    source_dir=FORMAL_CHARACTER_SOURCE_DIR,
)
validate_generated_registry_views(
    ctx,
    generated_views=generated_registry_views,
    committed_manifest=manifest,
    committed_capability_catalog=capability_catalog,
    manifest_path=MANIFEST_PATH,
    capability_catalog_path=CAPABILITY_CATALOG_PATH,
    source_dir=FORMAL_CHARACTER_SOURCE_DIR,
)
validate_no_live_scaffold_placeholders(ctx)
characters = manifest.get("characters", [])
validate_no_incomplete_live_validators(ctx, characters if isinstance(characters, list) else [])
validate_pair_interaction_ordering_contract(ctx)
matchups = manifest.get("matchups", {})
character_runtime_contract_bucket = formal_registry_contracts.get("manifest_character_runtime", {})
character_delivery_contract_bucket = formal_registry_contracts.get("manifest_character_delivery", {})
owned_pair_spec_contract_bucket = formal_registry_contracts.get("owned_pair_interaction_spec", {})
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
owned_pair_spec_required_string_fields = contract_field_list(
    ctx,
    owned_pair_spec_contract_bucket,
    "required_string_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.owned_pair_interaction_spec.required_string_fields",
)
owned_pair_spec_required_array_fields = contract_field_list(
    ctx,
    owned_pair_spec_contract_bucket,
    "required_array_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.owned_pair_interaction_spec.required_array_fields",
    allow_empty=True,
)
owned_pair_spec_required_positive_int_fields = contract_field_list(
    ctx,
    owned_pair_spec_contract_bucket,
    "required_positive_int_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.owned_pair_interaction_spec.required_positive_int_fields",
)
contract_field_list(
    ctx,
    owned_pair_spec_contract_bucket,
    "optional_string_fields",
    f"{FORMAL_REGISTRY_CONTRACTS_PATH}.owned_pair_interaction_spec.optional_string_fields",
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
if "pair_interaction_cases" in manifest:
    ctx.failures.append(f"{MANIFEST_PATH} must not define pair_interaction_cases; use characters[*].owned_pair_interaction_specs")
if "pair_interaction_specs" in manifest:
    ctx.failures.append(f"{MANIFEST_PATH} must not define pair_interaction_specs; use characters[*].owned_pair_interaction_specs")

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
pair_catalog = load_pair_catalog(
    ctx,
    export_script_path=PAIR_CATALOG_EXPORT_SCRIPT_PATH,
    manifest_path=MANIFEST_PATH,
)
derived_matchups = pair_catalog.get("matchups", {})
if not isinstance(derived_matchups, dict):
    ctx.failures.append(f"{PAIR_CATALOG_EXPORT_SCRIPT_PATH} missing matchups object")
    derived_matchups = {}
derived_pair_interaction_cases = pair_catalog.get("pair_interaction_cases", [])
if not isinstance(derived_pair_interaction_cases, list):
    ctx.failures.append(f"{PAIR_CATALOG_EXPORT_SCRIPT_PATH} missing pair_interaction_cases array")
    derived_pair_interaction_cases = []

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

for entry in characters:
    if not isinstance(entry, dict):
        continue
    character_id = str(entry.get("character_id", "")).strip()
    validator_script_path = str(entry.get("content_validator_script_path", "")).strip()
    if not validator_script_path:
        continue
    validate_entry_validator_structure(
        ctx,
        character_id=character_id,
        validator_script_path=validator_script_path,
    )

validate_capability_catalog(
    ctx,
    capability_catalog_path=CAPABILITY_CATALOG_PATH,
    characters=characters,
    manifest_path=MANIFEST_PATH,
    export_script_path=CAPABILITY_FACTS_EXPORT_SCRIPT_PATH,
)

for owner_index, raw_entry in enumerate(characters):
    if not isinstance(raw_entry, dict):
        continue
    owner_character_id = str(raw_entry.get("character_id", "")).strip() or str(owner_index)
    owned_specs = raw_entry.get("owned_pair_interaction_specs", [])
    if not isinstance(owned_specs, list):
        continue
    for spec_index, raw_spec in enumerate(owned_specs):
        if not isinstance(raw_spec, dict):
            continue
        validate_required_contract_fields(
            ctx,
            raw_spec,
            owned_pair_spec_required_string_fields,
            owned_pair_spec_required_array_fields,
            f"{MANIFEST_PATH} characters[{owner_character_id}].owned_pair_interaction_specs[{spec_index}]",
            owned_pair_spec_required_positive_int_fields,
        )

validate_pair_catalog(
    ctx,
    runtime_character_ids=character_validation["runtime_character_ids"],
    characters=characters,
    delivery_registry=delivery_registry,
    character_to_unit=character_validation["character_to_unit"],
    raw_matchups=matchups,
    derived_matchups=derived_matchups,
    pair_interaction_cases=derived_pair_interaction_cases,
    matchup_catalog_path=MANIFEST_PATH,
    delivery_registry_path=MANIFEST_PATH,
    scenario_registry_path=PAIR_INTERACTION_SCENARIO_REGISTRY_PATH,
    scenario_registry_export_script_path=PAIR_INTERACTION_SCENARIO_EXPORT_SCRIPT_PATH,
)

ctx.finish("formal character manifest, pair coverage, and anti-regression guards are aligned")
