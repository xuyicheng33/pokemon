from __future__ import annotations

import re

from repo_consistency_formal_character_gate_support import (
    collect_scope_tree,
    scan_legacy_formal_character_id_refs,
    validate_required_contract_fields,
    validator_test_prefix,
)


def _gdunit_test_pattern(test_name: str) -> str:
    return rf"func\s+test_{re.escape(test_name)}\s*\("


def validate_character_entries(
    ctx,
    *,
    manifest_path: str,
    baseline_registry_path: str,
    characters: list,
    delivery_entries_by_character: dict[str, dict],
    matchups: dict,
    character_runtime_required_string_fields: list[str],
    character_runtime_required_array_fields: list[str],
    character_delivery_required_string_fields: list[str],
    character_delivery_required_array_fields: list[str],
    validator_bad_case_suite_path: str,
    shared_suite_roots: list[str],
) -> dict[str, object]:
    character_to_unit: dict[str, str] = {}
    runtime_character_ids: list[str] = []
    seen_characters: set[str] = set()
    seen_units: set[str] = set()
    shared_suite_scope_paths = collect_scope_tree(ctx, shared_suite_roots)
    delivery_required_suite_paths_by_character: dict[str, list[str]] = {}
    baseline_registry_text = ctx.read_text(baseline_registry_path)
    if "BASELINE_SCRIPT_BY_CHARACTER_ID" in baseline_registry_text or "const CHARACTER_IDS" in baseline_registry_text:
        ctx.failures.append(f"{baseline_registry_path} must not keep manual baseline registry constants")
    baseline_loader_path = "src/shared/formal_character_baselines/formal_character_baseline_loader.gd"
    if "FormalCharacterManifestScript" not in baseline_registry_text:
        if "BaselineLoaderScript" not in baseline_registry_text:
            ctx.failures.append(f"{baseline_registry_path} must load manifest-backed formal character ids")
        else:
            baseline_loader_text = ctx.read_text(baseline_loader_path)
            if "FormalCharacterManifestScript" not in baseline_loader_text:
                ctx.failures.append(f"{baseline_loader_path} must load manifest-backed formal character ids")
    baseline_loader_text = ctx.read_text(baseline_loader_path)
    if 'entry.get("baseline_script_path"' not in baseline_loader_text:
        ctx.failures.append(f"{baseline_loader_path} must read baseline_script_path from manifest-backed runtime entries")
    if "BASELINE_SCRIPT_ROOT" in baseline_loader_text:
        ctx.failures.append(f"{baseline_loader_path} must not keep convention-based baseline root guessing")

    for entry in characters:
        character_id = str(entry.get("character_id", "")).strip()
        display_name = str(entry.get("display_name", "")).strip()
        unit_definition_id = str(entry.get("unit_definition_id", "")).strip()
        formal_setup_matchup_id = str(entry.get("formal_setup_matchup_id", "")).strip()
        pair_token = str(entry.get("pair_token", "")).strip()
        baseline_script_path = str(entry.get("baseline_script_path", "")).strip()
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
        delivery_entry = delivery_entries_by_character.get(character_id, {})
        if not delivery_entry:
            ctx.failures.append(f"formal delivery view missing character_id: {character_id}")
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
        if not pair_token:
            ctx.failures.append(f"formal manifest[{character_id}] missing pair_token")
        if not baseline_script_path:
            ctx.failures.append(f"formal manifest[{character_id}] missing baseline_script_path")
        else:
            ctx.require_exists(baseline_script_path, f"{character_id} formal baseline script")

        if not formal_setup_matchup_id:
            ctx.failures.append(f"formal manifest[{character_id}] missing formal_setup_matchup_id")
        else:
            matchup_spec = matchups.get(formal_setup_matchup_id, {})
            if not isinstance(matchup_spec, dict) or not matchup_spec:
                ctx.failures.append(f"formal manifest[{character_id}] formal_setup_matchup_id missing from {manifest_path}: {formal_setup_matchup_id}")
            else:
                if matchup_spec.get("test_only") is True:
                    ctx.failures.append(
                        f"formal manifest[{character_id}] formal_setup_matchup_id must not point to test_only matchup: {formal_setup_matchup_id}"
                    )
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

        validate_required_contract_fields(
            ctx,
            delivery_entry,
            character_delivery_required_string_fields,
            character_delivery_required_array_fields,
            f"formal delivery view[{character_id}]",
        )
        delivery_suite_path = str(delivery_entry.get("suite_path", suite_path)).strip() if isinstance(delivery_entry, dict) else suite_path
        delivery_required_suite_paths = delivery_entry.get("required_suite_paths", required_suite_paths) if isinstance(delivery_entry, dict) else required_suite_paths
        delivery_required_test_names = delivery_entry.get("required_test_names", required_test_names) if isinstance(delivery_entry, dict) else required_test_names
        delivery_design_needles = delivery_entry.get("design_needles", design_needles) if isinstance(delivery_entry, dict) else design_needles
        delivery_adjustment_needles = delivery_entry.get("adjustment_needles", adjustment_needles) if isinstance(delivery_entry, dict) else adjustment_needles
        delivery_surface_smoke_skill_id = str(delivery_entry.get("surface_smoke_skill_id", surface_smoke_skill_id)).strip() if isinstance(delivery_entry, dict) else surface_smoke_skill_id

        if not delivery_surface_smoke_skill_id:
            ctx.failures.append(f"formal delivery view[{character_id}] missing surface_smoke_skill_id")

        if not delivery_suite_path:
            ctx.failures.append(f"formal manifest[{character_id}] missing suite_path")
            suite_scope_paths: list[str] = []
        else:
            if not delivery_suite_path.startswith("test/"):
                ctx.failures.append(f"formal delivery view[{character_id}] suite_path must point into test/: {delivery_suite_path}")
            ctx.require_exists(delivery_suite_path, f"{character_id} suite")
            suite_scope_paths = [delivery_suite_path]

        if not isinstance(delivery_required_suite_paths, list):
            ctx.failures.append(f"formal delivery view[{character_id}] missing required_suite_paths")
            delivery_required_suite_paths = []
        delivery_required_suite_paths_by_character[character_id] = [
            str(rel_path).strip()
            for rel_path in delivery_required_suite_paths
            if str(rel_path).strip()
        ]
        for rel_path in delivery_required_suite_paths_by_character[character_id]:
            rel_path = str(rel_path)
            if not rel_path.startswith("test/"):
                ctx.failures.append(f"formal delivery view[{character_id}] required_suite_path must point into test/: {rel_path}")
            ctx.require_exists(rel_path, f"{character_id} required suite")
            suite_scope_paths.append(rel_path)

        if not isinstance(delivery_required_test_names, list) or not delivery_required_test_names:
            ctx.failures.append(f"formal delivery view[{character_id}] missing required_test_names")
        if not isinstance(delivery_design_needles, list) or not delivery_design_needles:
            ctx.failures.append(f"formal delivery view[{character_id}] missing design_needles")
        if not isinstance(delivery_adjustment_needles, list) or not delivery_adjustment_needles:
            ctx.failures.append(f"formal delivery view[{character_id}] missing adjustment_needles")

        if design_doc:
            for anchor_id in delivery_design_needles if isinstance(delivery_design_needles, list) else []:
                ctx.require_anchor(design_doc, str(anchor_id), f"{character_id} design anchor")
        if adjustment_doc:
            for anchor_id in delivery_adjustment_needles if isinstance(delivery_adjustment_needles, list) else []:
                ctx.require_anchor(adjustment_doc, str(anchor_id), f"{character_id} adjustment anchor")

        scoped_suite_paths = collect_scope_tree(ctx, suite_scope_paths)
        for test_name in delivery_required_test_names if isinstance(delivery_required_test_names, list) else []:
            test_pattern = _gdunit_test_pattern(str(test_name))
            ctx.require_regex_any(scoped_suite_paths, test_pattern, f"{character_id} regression anchor")
            if any(re.search(test_pattern, ctx.read_text(shared_path), re.M) is not None for shared_path in shared_suite_scope_paths):
                ctx.failures.append(
                    f"formal manifest[{character_id}] must not duplicate shared regression anchor in required_test_names: {test_name}"
                )

        if validator_script_path:
            if validator_bad_case_suite_path not in delivery_required_suite_paths_by_character[character_id]:
                ctx.failures.append(
                    f"formal delivery view[{character_id}] validator-backed character must expose {validator_bad_case_suite_path} in required_suite_paths"
                )
            validator_prefix = validator_test_prefix(validator_script_path)
            if validator_prefix and not any(
                str(test_name).startswith(f"formal_{validator_prefix}_validator_") and "bad_case_contract" in str(test_name)
                for test_name in delivery_required_test_names if isinstance(delivery_required_test_names, list)
            ):
                ctx.failures.append(
                    f"formal delivery view[{character_id}] validator-backed character must include formal_{validator_prefix}_validator_*bad_case_contract regression anchors"
                )

    ctx.failures.extend(scan_legacy_formal_character_id_refs(ctx))

    return {
        "character_to_unit": character_to_unit,
        "runtime_character_ids": runtime_character_ids,
    }
