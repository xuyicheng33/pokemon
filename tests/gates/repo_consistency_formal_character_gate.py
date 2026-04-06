from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


ctx = GateContext()
REGISTRY_PATH = "config/formal_character_registry.json"
MATCHUP_CATALOG_PATH = "config/formal_matchup_catalog.json"
VALIDATOR_BAD_CASE_SUITE_PATH = "tests/suites/extension_validation_contract_suite.gd"
FORMAL_PAIR_SMOKE_SUITE_PATH = "tests/suites/formal_character_pair_smoke_suite.gd"


def validator_test_prefix(script_path: str) -> str:
    stem = Path(script_path).stem
    match = re.fullmatch(r"content_snapshot_formal_(.+)_validator", stem)
    return "" if match is None else match.group(1)


def collect_suite_refs(text: str) -> list[str]:
    refs: list[str] = []
    for pattern in [
        re.compile(r'preload\("res://(tests/suites/[^"]+\.gd)"\)'),
        re.compile(r'extends "res://(tests/suites/[^"]+\.gd)"'),
    ]:
        refs.extend(pattern.findall(text))
    return refs


def collect_scope_tree(start_paths: list[str]) -> list[str]:
    discovered: set[str] = set()
    pending_paths: list[str] = list(start_paths)
    while pending_paths:
        rel_path = pending_paths.pop()
        if rel_path in discovered:
            continue
        if not Path(rel_path).exists():
            continue
        discovered.add(rel_path)
        for child_rel_path in collect_suite_refs(ctx.read_text(rel_path)):
            pending_paths.append(child_rel_path)
    return sorted(discovered)


formal_character_registry = ctx.load_json_array(REGISTRY_PATH, "formal character registry")
if not formal_character_registry:
    ctx.failures.append(f"{REGISTRY_PATH} must list at least one formal character")
matchup_catalog = ctx.load_json_object(MATCHUP_CATALOG_PATH, "formal matchup catalog")
matchups = matchup_catalog.get("matchups", {})
pair_surface_cases = matchup_catalog.get("pair_surface_cases", [])
pair_interaction_cases = matchup_catalog.get("pair_interaction_cases", [])
if not isinstance(matchups, dict):
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} missing matchups dictionary")
    matchups = {}
if not isinstance(pair_surface_cases, list):
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases must be an array")
    pair_surface_cases = []
if not isinstance(pair_interaction_cases, list):
    ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases must be an array")
    pair_interaction_cases = []

runtime_registry_text = ctx.read_text("src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd")
if 'REGISTRY_PATH := "res://config/formal_character_registry.json"' not in runtime_registry_text:
    ctx.failures.append("runtime formal character validator registry must read config/formal_character_registry.json directly")
if "content_validator_script_path" not in runtime_registry_text:
    ctx.failures.append("runtime formal character validator registry must resolve validator paths from registry entries")
if "FORMAL_CHARACTER_DESCRIPTORS" in runtime_registry_text or '"validator_script": preload(' in runtime_registry_text:
    ctx.failures.append("runtime formal character validator registry must not keep a second hard-coded character descriptor list")

sample_factory_text = ctx.read_text("src/composition/sample_battle_factory.gd")
if 'entry.get("formal_setup_matchup_id"' not in sample_factory_text:
    ctx.failures.append("SampleBattleFactory.build_formal_character_setup must read formal_setup_matchup_id from registry")
if "return call(sample_setup_method, side_regular_skill_overrides)" in sample_factory_text:
    ctx.failures.append("SampleBattleFactory.build_formal_character_setup must not route formal setup through sample_setup_method")
if "func formal_unit_definition_ids()" not in sample_factory_text:
    ctx.failures.append("SampleBattleFactory must expose formal_unit_definition_ids for definition-facing callers")
if "func formal_pair_interaction_cases()" not in sample_factory_text:
    ctx.failures.append("SampleBattleFactory must expose formal_pair_interaction_cases from the catalog")

matchup_catalog_text = ctx.read_text("src/composition/sample_battle_factory_matchup_catalog.gd")
if 'DEFAULT_CATALOG_PATH := "res://config/formal_matchup_catalog.json"' not in matchup_catalog_text:
    ctx.failures.append("SampleBattleFactoryMatchupCatalog must read config/formal_matchup_catalog.json directly")
for needle in ["pair_surface_cases", "pair_interaction_cases"]:
    if f'"{needle}"' not in matchup_catalog_text:
        ctx.failures.append(f"SampleBattleFactoryMatchupCatalog must validate {needle}")

pair_suite_text = ctx.read_text(FORMAL_PAIR_SMOKE_SUITE_PATH)
if 'preload("res://tests/suites/formal_character_pair_smoke/surface_suite.gd")' not in pair_suite_text:
    ctx.failures.append("formal pair smoke wrapper must preload the surface suite")
if 'preload("res://tests/suites/formal_character_pair_smoke/interaction_suite.gd")' not in pair_suite_text:
    ctx.failures.append("formal pair smoke wrapper must preload the interaction suite")

run_all_text = ctx.read_text("tests/run_all.gd")
pending_suite_paths: list[str] = collect_suite_refs(run_all_text)
for entry in formal_character_registry:
    suite_path = str(entry.get("suite_path", ""))
    if suite_path:
        pending_suite_paths.append(suite_path)

reachable_suite_paths: set[str] = set()
while pending_suite_paths:
    suite_path = pending_suite_paths.pop()
    if suite_path in reachable_suite_paths:
        continue
    if not Path(suite_path).exists():
        continue
    reachable_suite_paths.add(suite_path)
    for child_suite in collect_suite_refs(ctx.read_text(suite_path)):
        pending_suite_paths.append(child_suite)

character_to_unit: dict[str, str] = {}
formal_character_ids: list[str] = []
seen_formal_characters: set[str] = set()

for entry in formal_character_registry:
    if not isinstance(entry, dict):
        continue
    character_id = str(entry.get("character_id", "")).strip()
    unit_definition_id = str(entry.get("unit_definition_id", "")).strip()
    design_doc = str(entry.get("design_doc", ""))
    adjustment_doc = str(entry.get("adjustment_doc", ""))
    suite_path = str(entry.get("suite_path", ""))
    formal_setup_matchup_id = str(entry.get("formal_setup_matchup_id", "")).strip()
    content_validator_script_path = str(entry.get("content_validator_script_path", ""))
    required_content_paths = entry.get("required_content_paths", [])
    required_suite_paths = entry.get("required_suite_paths", [])
    required_test_names = entry.get("required_test_names", [])
    design_needles = entry.get("design_needles", [])
    adjustment_needles = entry.get("adjustment_needles", [])
    suite_scope_paths: list[str] = []

    if not character_id:
        ctx.failures.append("formal character registry entry missing character_id")
        continue
    if character_id in seen_formal_characters:
        ctx.failures.append(f"formal character registry duplicated character_id: {character_id}")
    seen_formal_characters.add(character_id)
    formal_character_ids.append(character_id)

    if not unit_definition_id:
        ctx.failures.append(f"formal character registry[{character_id}] missing unit_definition_id")
    character_to_unit[character_id] = unit_definition_id
    if not design_doc:
        ctx.failures.append(f"formal character registry[{character_id}] missing design_doc")
    else:
        ctx.require_exists(design_doc, f"{character_id} design doc")
    if not adjustment_doc:
        ctx.failures.append(f"formal character registry[{character_id}] missing adjustment_doc")
    else:
        ctx.require_exists(adjustment_doc, f"{character_id} adjustment doc")
    if not suite_path:
        ctx.failures.append(f"formal character registry[{character_id}] missing suite_path")
    else:
        ctx.require_exists(suite_path, f"{character_id} suite")
        suite_scope_paths.append(suite_path)
    if not formal_setup_matchup_id:
        ctx.failures.append(f"formal character registry[{character_id}] missing formal_setup_matchup_id")
    else:
        matchup_spec = matchups.get(formal_setup_matchup_id, {})
        if not isinstance(matchup_spec, dict) or not matchup_spec:
            ctx.failures.append(f"formal character registry[{character_id}] formal_setup_matchup_id missing from {MATCHUP_CATALOG_PATH}: {formal_setup_matchup_id}")
        else:
            p1_units = matchup_spec.get("p1_units", [])
            if not isinstance(p1_units, list) or not p1_units:
                ctx.failures.append(f"formal character registry[{character_id}] formal_setup_matchup_id must define non-empty p1_units: {formal_setup_matchup_id}")
            elif unit_definition_id and str(p1_units[0]).strip() != unit_definition_id:
                ctx.failures.append(
                    f"formal character registry[{character_id}] formal_setup_matchup_id must open with its own unit_definition_id: {formal_setup_matchup_id}"
                )
    if content_validator_script_path:
        ctx.require_exists(content_validator_script_path, f"{character_id} content validator script")
        validator_text = ctx.read_text(content_validator_script_path)
        validator_prefix = validator_test_prefix(content_validator_script_path)
        if not content_validator_script_path.endswith("_validator.gd"):
            ctx.failures.append(f"formal character registry[{character_id}] content validator must end with _validator.gd: {content_validator_script_path}")
        else:
            validator_path_prefix = content_validator_script_path.removesuffix("_validator.gd")
            for bucket_path, bucket_label in [
                (f"{validator_path_prefix}_unit_passive_contracts.gd", "unit_passive_contracts"),
                (f"{validator_path_prefix}_skill_effect_contracts.gd", "skill_effect_contracts"),
                (f"{validator_path_prefix}_ultimate_domain_contracts.gd", "ultimate_domain_contracts"),
            ]:
                ctx.require_exists(bucket_path, f"{character_id} {bucket_label} validator bucket")
                if f'preload("res://{bucket_path}")' not in validator_text:
                    ctx.failures.append(
                        f"formal character registry[{character_id}] entry validator must preload {bucket_label}: {bucket_path}"
                    )
            for bucket_var in ["_unit_passive_contracts", "_skill_effect_contracts", "_ultimate_domain_contracts"]:
                if f"{bucket_var}.validate(self, content_index, errors)" not in validator_text:
                    ctx.failures.append(
                        f"formal character registry[{character_id}] entry validator must dispatch {bucket_var}.validate(self, content_index, errors)"
                    )
            if not validator_prefix:
                ctx.failures.append(
                    f"formal character registry[{character_id}] content validator name must match content_snapshot_formal_<name>_validator.gd"
                )
    if not isinstance(required_suite_paths, list) or not required_suite_paths:
        ctx.failures.append(f"formal character registry[{character_id}] missing required_suite_paths")
    else:
        for rel_path in required_suite_paths:
            rel_path = str(rel_path)
            ctx.require_exists(rel_path, f"{character_id} required suite")
            suite_scope_paths.append(rel_path)
            if rel_path not in reachable_suite_paths:
                ctx.failures.append(
                    f"formal character registry[{character_id}] required_suite_path is not reachable from tests/run_all.gd wrapper tree: {rel_path}"
                )
        if content_validator_script_path and VALIDATOR_BAD_CASE_SUITE_PATH not in required_suite_paths:
            ctx.failures.append(
                f"formal character registry[{character_id}] validator-backed character must include {VALIDATOR_BAD_CASE_SUITE_PATH} in required_suite_paths"
            )
    if not isinstance(required_test_names, list) or not required_test_names:
        ctx.failures.append(f"formal character registry[{character_id}] missing required_test_names")
    else:
        scoped_suite_paths = collect_scope_tree(suite_scope_paths)
        for test_name in required_test_names:
            ctx.require_contains_any(
                scoped_suite_paths,
                f'runner.run_test("{str(test_name)}"',
                f"{character_id} regression anchor",
            )
        if content_validator_script_path:
            validator_prefix = validator_test_prefix(content_validator_script_path)
            if validator_prefix and not any(
                str(test_name).startswith(f"formal_{validator_prefix}_validator_") and "bad_case_contract" in str(test_name)
                for test_name in required_test_names
            ):
                ctx.failures.append(
                    f"formal character registry[{character_id}] validator-backed character must include formal_{validator_prefix}_validator_*bad_case_contract regression anchors"
                )
    if not isinstance(required_content_paths, list) or not required_content_paths:
        ctx.failures.append(f"formal character registry[{character_id}] missing required_content_paths")
    else:
        for rel_path in required_content_paths:
            ctx.require_exists(str(rel_path), f"{character_id} content asset")
    if not isinstance(design_needles, list) or not design_needles:
        ctx.failures.append(f"formal character registry[{character_id}] missing design_needles")
    elif design_doc:
        for anchor_id in design_needles:
            resolved_anchor_id = str(anchor_id).removeprefix("anchor:")
            ctx.require_anchor(design_doc, resolved_anchor_id, f"{character_id} design anchor")
    if not isinstance(adjustment_needles, list) or not adjustment_needles:
        ctx.failures.append(f"formal character registry[{character_id}] missing adjustment_needles")
    elif adjustment_doc:
        for anchor_id in adjustment_needles:
            resolved_anchor_id = str(anchor_id).removeprefix("anchor:")
            ctx.require_anchor(adjustment_doc, resolved_anchor_id, f"{character_id} adjustment anchor")

expected_surface_pairs = {
    f"{left}->{right}"
    for left in formal_character_ids
    for right in formal_character_ids
    if left != right
}
actual_surface_pairs: set[str] = set()
for case_index, raw_case in enumerate(pair_surface_cases):
    if not isinstance(raw_case, dict):
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] must be object")
        continue
    test_name = str(raw_case.get("test_name", "")).strip()
    matchup_id = str(raw_case.get("matchup_id", "")).strip()
    p1_character_id = str(raw_case.get("p1_character_id", "")).strip()
    p2_character_id = str(raw_case.get("p2_character_id", "")).strip()
    p1_unit_definition_id = str(raw_case.get("p1_unit_definition_id", "")).strip()
    p2_unit_definition_id = str(raw_case.get("p2_unit_definition_id", "")).strip()
    if not test_name:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] missing test_name")
    if matchup_id not in matchups:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] unknown matchup_id: {matchup_id}")
    if p1_character_id not in character_to_unit or p2_character_id not in character_to_unit:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] references unknown formal character id")
        continue
    if p1_character_id == p2_character_id:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] must be directional and cannot target the same character twice")
        continue
    if p1_unit_definition_id != character_to_unit[p1_character_id]:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] p1_unit_definition_id drifted from registry")
    if p2_unit_definition_id != character_to_unit[p2_character_id]:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_surface_cases[{case_index}] p2_unit_definition_id drifted from registry")
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
    "<->".join(sorted([formal_character_ids[left_index], formal_character_ids[right_index]]))
    for left_index in range(len(formal_character_ids))
    for right_index in range(left_index + 1, len(formal_character_ids))
}
actual_interaction_pairs: set[str] = set()
for case_index, raw_case in enumerate(pair_interaction_cases):
    if not isinstance(raw_case, dict):
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases[{case_index}] must be object")
        continue
    test_name = str(raw_case.get("test_name", "")).strip()
    scenario_id = str(raw_case.get("scenario_id", "")).strip()
    matchup_id = str(raw_case.get("matchup_id", "")).strip()
    character_ids = raw_case.get("character_ids", [])
    if not test_name:
        ctx.failures.append(f"{MATCHUP_CATALOG_PATH} pair_interaction_cases[{case_index}] missing test_name")
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

if FORMAL_PAIR_SMOKE_SUITE_PATH not in reachable_suite_paths:
    ctx.failures.append(f"{FORMAL_PAIR_SMOKE_SUITE_PATH} must stay reachable from tests/run_all.gd wrapper tree")

ctx.finish("formal registry, matchup catalog, suite tree, and delivery anchors are aligned")
