from __future__ import annotations

from repo_consistency_formal_character_gate_support import (
    collect_scope_tree,
    collect_suite_refs,
    validate_required_contract_fields,
    validator_test_prefix,
)


def validate_character_entries(
    ctx,
    *,
    manifest_path: str,
    characters: list,
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
    reachable_suite_paths: set[str] = set()
    pending_suite_paths: list[str] = collect_suite_refs(ctx.read_text("tests/run_all.gd"))
    shared_suite_scope_paths = collect_scope_tree(ctx, shared_suite_roots)

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
                ctx.failures.append(f"formal manifest[{character_id}] formal_setup_matchup_id missing from {manifest_path}: {formal_setup_matchup_id}")
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
            if validator_bad_case_suite_path not in required_suite_paths:
                ctx.failures.append(
                    f"formal manifest[{character_id}] validator-backed character must include {validator_bad_case_suite_path} in required_suite_paths"
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

    return {
        "character_to_unit": character_to_unit,
        "runtime_character_ids": runtime_character_ids,
    }
