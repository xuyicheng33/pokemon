from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


ctx = GateContext()
REGISTRY_PATH = "config/formal_character_registry.json"
VALIDATOR_BAD_CASE_SUITE_PATH = "tests/suites/extension_validation_contract_suite.gd"
FORMAL_PAIR_SMOKE_SUITE_PATH = "tests/suites/formal_character_pair_smoke_suite.gd"


def validator_test_prefix(script_path: str) -> str:
    stem = Path(script_path).stem
    match = re.fullmatch(r"content_snapshot_formal_(.+)_validator", stem)
    return "" if match is None else match.group(1)


formal_character_registry = ctx.load_json_array(REGISTRY_PATH, "formal character registry")
if not formal_character_registry:
    ctx.failures.append(f"{REGISTRY_PATH} must list at least one formal character")
runtime_registry_text = ctx.read_text("src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd")
if 'REGISTRY_PATH := "res://config/formal_character_registry.json"' not in runtime_registry_text:
    ctx.failures.append("runtime formal character validator registry must read config/formal_character_registry.json directly")
if "content_validator_script_path" not in runtime_registry_text:
    ctx.failures.append("runtime formal character validator registry must resolve validator paths from docs registry entries")
if "FORMAL_CHARACTER_DESCRIPTORS" in runtime_registry_text or '"validator_script": preload(' in runtime_registry_text:
    ctx.failures.append("runtime formal character validator registry must not keep a second hard-coded character descriptor list")

sample_factory_text = ctx.read_text("src/composition/sample_battle_factory.gd")
if 'entry.get("formal_setup_matchup_id"' not in sample_factory_text:
    ctx.failures.append("SampleBattleFactory.build_formal_character_setup must read formal_setup_matchup_id from registry")
if "return call(sample_setup_method, side_regular_skill_overrides)" in sample_factory_text:
    ctx.failures.append("SampleBattleFactory.build_formal_character_setup must not route formal setup through sample_setup_method")
run_all_text = ctx.read_text("tests/run_all.gd")
suite_ref_patterns = [
    re.compile(r'preload\("res://(tests/suites/[^"]+\.gd)"\)'),
    re.compile(r'extends "res://(tests/suites/[^"]+\.gd)"'),
]
seen_formal_characters: set[str] = set()
reachable_suite_paths: set[str] = set()


def collect_suite_refs(text: str) -> list[str]:
    refs: list[str] = []
    for pattern in suite_ref_patterns:
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


pending_suite_paths: list[str] = collect_suite_refs(run_all_text)

for entry in formal_character_registry:
    if not isinstance(entry, dict):
        continue
    suite_path = str(entry.get("suite_path", ""))
    if suite_path != "":
        pending_suite_paths.append(suite_path)

while pending_suite_paths:
    suite_path = pending_suite_paths.pop()
    if suite_path in reachable_suite_paths:
        continue
    if not Path(suite_path).exists():
        continue
    reachable_suite_paths.add(suite_path)
    for child_suite in collect_suite_refs(ctx.read_text(suite_path)):
        pending_suite_paths.append(child_suite)

for entry in formal_character_registry:
    character_id = str(entry.get("character_id", ""))
    unit_definition_id = str(entry.get("unit_definition_id", ""))
    design_doc = str(entry.get("design_doc", ""))
    adjustment_doc = str(entry.get("adjustment_doc", ""))
    suite_path = str(entry.get("suite_path", ""))
    sample_setup_method = str(entry.get("sample_setup_method", ""))
    formal_setup_matchup_id = str(entry.get("formal_setup_matchup_id", ""))
    content_validator_script_path = str(entry.get("content_validator_script_path", ""))
    required_content_paths = entry.get("required_content_paths", [])
    required_suite_paths = entry.get("required_suite_paths", [])
    required_test_names = entry.get("required_test_names", [])
    design_needles = entry.get("design_needles", [])
    adjustment_needles = entry.get("adjustment_needles", [])
    suite_scope_paths: list[str] = []
    if character_id == "":
        ctx.failures.append("formal character registry entry missing character_id")
        continue
    if character_id in seen_formal_characters:
        ctx.failures.append(f"formal character registry duplicated character_id: {character_id}")
    seen_formal_characters.add(character_id)
    if unit_definition_id == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing unit_definition_id")
    if design_doc == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing design_doc")
    else:
        ctx.require_exists(design_doc, f"{character_id} design doc")
    if adjustment_doc == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing adjustment_doc")
    else:
        ctx.require_exists(adjustment_doc, f"{character_id} adjustment doc")
    if suite_path == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing suite_path")
    else:
        ctx.require_exists(suite_path, f"{character_id} suite")
        suite_scope_paths.append(suite_path)
    if sample_setup_method == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing sample_setup_method")
    elif f"func {sample_setup_method}(" not in sample_factory_text:
        ctx.failures.append(f"src/composition/sample_battle_factory.gd missing sample setup builder: {sample_setup_method}")
    if formal_setup_matchup_id == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing formal_setup_matchup_id")
    elif f'"{formal_setup_matchup_id}"' not in ctx.read_text("src/composition/sample_battle_factory_matchup_catalog.gd"):
        ctx.failures.append(
            f"formal character registry[{character_id}] formal_setup_matchup_id missing from SampleBattleFactory matchup catalog: {formal_setup_matchup_id}"
        )
    if content_validator_script_path != "":
        ctx.require_exists(content_validator_script_path, f"{character_id} content validator script")
        validator_text = ctx.read_text(content_validator_script_path)
        validator_prefix = validator_test_prefix(content_validator_script_path)
        if not content_validator_script_path.endswith("_validator.gd"):
            ctx.failures.append(f"formal character registry[{character_id}] content validator must end with _validator.gd: {content_validator_script_path}")
        else:
            validator_path_prefix = content_validator_script_path.removesuffix("_validator.gd")
            expected_bucket_paths = [
                (f"{validator_path_prefix}_unit_passive_contracts.gd", "unit_passive_contracts"),
                (f"{validator_path_prefix}_skill_effect_contracts.gd", "skill_effect_contracts"),
                (f"{validator_path_prefix}_ultimate_domain_contracts.gd", "ultimate_domain_contracts"),
            ]
            for bucket_path, bucket_label in expected_bucket_paths:
                ctx.require_exists(bucket_path, f"{character_id} {bucket_label} validator bucket")
                preload_path = 'preload("res://%s")' % bucket_path
                if preload_path not in validator_text:
                    ctx.failures.append(
                        f"formal character registry[{character_id}] entry validator must preload {bucket_label}: {bucket_path}"
                    )
            for bucket_var in ["_unit_passive_contracts", "_skill_effect_contracts", "_ultimate_domain_contracts"]:
                if f"{bucket_var}.validate(self, content_index, errors)" not in validator_text:
                    ctx.failures.append(
                        f"formal character registry[{character_id}] entry validator must dispatch {bucket_var}.validate(self, content_index, errors)"
                    )
    if not isinstance(required_suite_paths, list) or not required_suite_paths:
        ctx.failures.append(f"formal character registry[{character_id}] missing required_suite_paths")
    else:
        for rel_path in required_suite_paths:
            ctx.require_exists(str(rel_path), f"{character_id} required suite")
            suite_scope_paths.append(str(rel_path))
            if str(rel_path) not in reachable_suite_paths:
                ctx.failures.append(
                    f"formal character registry[{character_id}] required_suite_path is not reachable from tests/run_all.gd wrapper tree: {rel_path}"
                )
        if FORMAL_PAIR_SMOKE_SUITE_PATH not in required_suite_paths:
            ctx.failures.append(
                f"formal character registry[{character_id}] must include {FORMAL_PAIR_SMOKE_SUITE_PATH} in required_suite_paths"
            )
        if content_validator_script_path != "" and VALIDATOR_BAD_CASE_SUITE_PATH not in required_suite_paths:
            ctx.failures.append(
                f"formal character registry[{character_id}] validator-backed character must include {VALIDATOR_BAD_CASE_SUITE_PATH} in required_suite_paths"
            )
    if not isinstance(required_test_names, list) or not required_test_names:
        ctx.failures.append(f"formal character registry[{character_id}] missing required_test_names")
    else:
        for test_name in required_test_names:
            scoped_suite_paths = collect_scope_tree(suite_scope_paths)
            ctx.require_contains_any(
                scoped_suite_paths,
                'runner.run_test("%s"' % str(test_name),
                f"{character_id} regression anchor",
            )
        if not any(str(test_name).startswith("formal_pair_") for test_name in required_test_names):
            ctx.failures.append(
                f"formal character registry[{character_id}] must include at least one formal_pair_*_manager_smoke_contract anchor"
            )
        if content_validator_script_path != "":
            if validator_prefix == "":
                ctx.failures.append(
                    f"formal character registry[{character_id}] content validator name must match content_snapshot_formal_<name>_validator.gd"
                )
            elif not any(
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
    elif design_doc != "":
        for needle in design_needles:
            ctx.require_contains(design_doc, str(needle), f"{character_id} design anchor")
    if not isinstance(adjustment_needles, list) or not adjustment_needles:
        ctx.failures.append(f"formal character registry[{character_id}] missing adjustment_needles")
    elif adjustment_doc != "":
        for needle in adjustment_needles:
            ctx.require_contains(adjustment_doc, str(needle), f"{character_id} adjustment anchor")

ctx.finish("formal character registry, suite tree, and asset delivery surface are aligned")
