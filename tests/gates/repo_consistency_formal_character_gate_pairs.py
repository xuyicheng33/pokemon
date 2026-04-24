from __future__ import annotations

import re


def _unordered_pair_key(left_character_id: str, right_character_id: str) -> str:
    return "<->".join(sorted([left_character_id, right_character_id]))


def _matchup_test_only(ctx, matchup_catalog_path: str, matchup_id: str, raw_matchup: dict) -> bool:
    if "test_only" not in raw_matchup:
        return False
    test_only = raw_matchup.get("test_only")
    if not isinstance(test_only, bool):
        ctx.failures.append(f"{matchup_catalog_path} matchup[{matchup_id}].test_only must be boolean")
        return False
    return test_only


def _runner_method_names(scenario_key: str) -> set[str]:
    method_names = {f"run_{scenario_key}"}
    parts = scenario_key.split("_", 2)
    if len(parts) == 3:
        method_names.add(f"run_{parts[0]}_vs_{parts[1]}_{parts[2]}")
    return method_names


def _implemented_runner_methods(ctx, scenario_registry_path: str) -> set[str]:
    registry_text = ctx.read_text(scenario_registry_path)
    for stale_needle in [
        "const GojoCasesScript",
        "const KashimoCasesScript",
        "const ObitoCasesScript",
        '"gojo_sukuna_domain_cleanup": Callable',
    ]:
        if stale_needle in registry_text:
            ctx.failures.append(
                f"{scenario_registry_path} must auto-discover pair interaction runners instead of keeping manual mapping: {stale_needle}"
            )

    support_dir = ctx.root / "tests/support/formal_pair_interaction"
    implemented: set[str] = set()
    for path in sorted(support_dir.glob("*_cases.gd")):
        rel_path = str(path.relative_to(ctx.root))
        text = path.read_text(encoding="utf-8")
        for forbidden in ["TODO:", "interaction placeholder", "pass_result(\""]:
            if forbidden in text:
                ctx.failures.append(f"{rel_path} must not keep placeholder interaction runner code: {forbidden}")
        for match in re.finditer(r"func\s+run_([A-Za-z0-9_]+)\s*\(", text):
            method_name = f"run_{match.group(1)}"
            if method_name in implemented:
                ctx.failures.append(f"duplicated pair interaction runner method: {method_name}")
            implemented.add(method_name)
    return implemented


def validate_pair_catalog(
    ctx,
    *,
    runtime_character_ids: list[str],
    characters: list[dict],
    delivery_registry: list[dict],
    character_to_unit: dict[str, str],
    raw_matchups: dict,
    derived_matchups: dict,
    pair_interaction_cases: list,
    matchup_catalog_path: str,
    delivery_registry_path: str,
    scenario_registry_path: str,
) -> None:
    surface_skill_by_character = {
        str(entry.get("character_id", "")).strip(): str(entry.get("surface_smoke_skill_id", "")).strip()
        for entry in delivery_registry
        if isinstance(entry, dict)
    }
    expected_surface_pairs = {
        f"{left}->{right}"
        for left in runtime_character_ids
        for right in runtime_character_ids
        if left != right
    }
    matchup_direction_by_id: dict[str, tuple[str, str]] = {}
    generated_matchup_by_direction: dict[tuple[str, str], str] = {}
    test_only_matchup_ids: set[str] = set()
    actual_surface_pairs: set[str] = set()
    for matchup_id, raw_matchup in raw_matchups.items():
        if not isinstance(raw_matchup, dict):
            continue
        normalized_matchup_id = str(matchup_id)
        test_only = _matchup_test_only(ctx, matchup_catalog_path, normalized_matchup_id, raw_matchup)
        p1_units = raw_matchup.get("p1_units", [])
        p2_units = raw_matchup.get("p2_units", [])
        if not isinstance(p1_units, list) or not p1_units or not isinstance(p2_units, list) or not p2_units:
            continue
        p1_character_id = next((character_id for character_id, unit_id in character_to_unit.items() if unit_id == str(p1_units[0]).strip()), "")
        p2_character_id = next((character_id for character_id, unit_id in character_to_unit.items() if unit_id == str(p2_units[0]).strip()), "")
        if not p1_character_id or not p2_character_id or p1_character_id == p2_character_id or test_only:
            continue
        ctx.failures.append(
            f"{matchup_catalog_path} raw matchups must not hand-write non-test_only formal pair matchup: {normalized_matchup_id}"
        )

    for matchup_id, raw_matchup in derived_matchups.items():
        if not isinstance(raw_matchup, dict):
            continue
        normalized_matchup_id = str(matchup_id)
        test_only = _matchup_test_only(ctx, matchup_catalog_path, normalized_matchup_id, raw_matchup)
        p1_units = raw_matchup.get("p1_units", [])
        p2_units = raw_matchup.get("p2_units", [])
        if not isinstance(p1_units, list) or not p1_units or not isinstance(p2_units, list) or not p2_units:
            continue
        p1_character_id = next((character_id for character_id, unit_id in character_to_unit.items() if unit_id == str(p1_units[0]).strip()), "")
        p2_character_id = next((character_id for character_id, unit_id in character_to_unit.items() if unit_id == str(p2_units[0]).strip()), "")
        if not p1_character_id or not p2_character_id:
            continue
        matchup_direction_by_id[normalized_matchup_id] = (p1_character_id, p2_character_id)
        if test_only:
            test_only_matchup_ids.add(normalized_matchup_id)
        if p1_character_id == p2_character_id and not test_only:
            ctx.failures.append(f"{matchup_catalog_path} same-character matchup must declare test_only: {normalized_matchup_id}")
        if test_only or p1_character_id == p2_character_id:
            continue
        generated_matchup_by_direction[(p1_character_id, p2_character_id)] = normalized_matchup_id
        pair_key = f"{p1_character_id}->{p2_character_id}"
        if pair_key in actual_surface_pairs:
            ctx.failures.append(f"{matchup_catalog_path} duplicated formal directed matchup for generated surface coverage: {pair_key}")
        actual_surface_pairs.add(pair_key)
        if not surface_skill_by_character.get(p1_character_id):
            ctx.failures.append(f"{delivery_registry_path} missing surface_smoke_skill_id for generated surface pair source: {p1_character_id}")
        if not surface_skill_by_character.get(p2_character_id):
            ctx.failures.append(f"{delivery_registry_path} missing surface_smoke_skill_id for generated surface pair target: {p2_character_id}")
    missing_surface_pairs = sorted(expected_surface_pairs - actual_surface_pairs)
    if missing_surface_pairs:
        ctx.failures.append(f"{matchup_catalog_path} missing directed generated surface coverage: {', '.join(missing_surface_pairs)}")
    extra_surface_pairs = sorted(actual_surface_pairs - expected_surface_pairs)
    if extra_surface_pairs:
        ctx.failures.append(f"{matchup_catalog_path} contains non-matrix generated surface coverage: {', '.join(extra_surface_pairs)}")

    expected_interaction_pairs = {
        _unordered_pair_key(runtime_character_ids[left_index], runtime_character_ids[right_index])
        for left_index in range(len(runtime_character_ids))
        for right_index in range(left_index + 1, len(runtime_character_ids))
    }
    expected_directional_interaction_cases: set[tuple[str, str, str, str]] = set()
    expected_scenario_keys_by_pair: dict[str, str] = {}
    runtime_index_by_character = {
        character_id: index for index, character_id in enumerate(runtime_character_ids)
    }
    seen_owned_pairs: set[str] = set()
    for owner_index, raw_entry in enumerate(characters):
        if not isinstance(raw_entry, dict):
            ctx.failures.append(f"{matchup_catalog_path} characters[{owner_index}] must be object")
            continue
        owner_character_id = str(raw_entry.get("character_id", "")).strip()
        owned_specs = raw_entry.get("owned_pair_interaction_specs", [])
        if not isinstance(owned_specs, list):
            ctx.failures.append(
                f"{matchup_catalog_path} characters[{owner_character_id or owner_index}].owned_pair_interaction_specs must be an array"
            )
            continue
        expected_other_character_ids = set(runtime_character_ids[:owner_index])
        seen_other_character_ids: set[str] = set()
        for spec_index, raw_spec in enumerate(owned_specs):
            if not isinstance(raw_spec, dict):
                ctx.failures.append(
                    f"{matchup_catalog_path} characters[{owner_character_id}].owned_pair_interaction_specs[{spec_index}] must be object"
                )
                continue
            other_character_id = str(raw_spec.get("other_character_id", "")).strip()
            if not other_character_id:
                continue
            if other_character_id not in runtime_index_by_character:
                ctx.failures.append(
                    f"{matchup_catalog_path} characters[{owner_character_id}].owned_pair_interaction_specs[{spec_index}] references unknown other_character_id: {other_character_id}"
                )
                continue
            if runtime_index_by_character[other_character_id] >= owner_index:
                ctx.failures.append(
                    f"{matchup_catalog_path} characters[{owner_character_id}].owned_pair_interaction_specs[{spec_index}] must only target earlier manifest characters: {other_character_id}"
                )
                continue
            if other_character_id in seen_other_character_ids:
                ctx.failures.append(
                    f"{matchup_catalog_path} characters[{owner_character_id}] duplicated owned pair target: {other_character_id}"
                )
                continue
            seen_other_character_ids.add(other_character_id)
            scenario_key = str(raw_spec.get("scenario_key", "")).strip()
            pair_key = _unordered_pair_key(owner_character_id, other_character_id)
            if pair_key in seen_owned_pairs:
                ctx.failures.append(f"{matchup_catalog_path} duplicated owned pair declaration: {pair_key}")
                continue
            seen_owned_pairs.add(pair_key)
            if pair_key in expected_scenario_keys_by_pair:
                ctx.failures.append(f"{matchup_catalog_path} duplicated unordered pair scenario: {pair_key}")
                continue
            expected_scenario_keys_by_pair[pair_key] = scenario_key
            owner_initiator_matchup_id = generated_matchup_by_direction.get((owner_character_id, other_character_id), "")
            owner_responder_matchup_id = generated_matchup_by_direction.get((other_character_id, owner_character_id), "")
            if not owner_initiator_matchup_id or not owner_responder_matchup_id:
                continue
            expected_directional_interaction_cases.add(
                (owner_character_id, other_character_id, owner_initiator_matchup_id, scenario_key)
            )
            expected_directional_interaction_cases.add(
                (other_character_id, owner_character_id, owner_responder_matchup_id, scenario_key)
            )
        missing_other_character_ids = sorted(expected_other_character_ids - seen_other_character_ids)
        if missing_other_character_ids:
            ctx.failures.append(
                f"{matchup_catalog_path} characters[{owner_character_id}] missing owned_pair_interaction_specs coverage: {', '.join(missing_other_character_ids)}"
            )
            continue

    actual_interaction_pairs: set[str] = set()
    actual_directional_cases: set[tuple[str, str, str, str]] = set()
    actual_test_names: set[str] = set()
    implemented_runner_methods = _implemented_runner_methods(ctx, scenario_registry_path)
    actual_scenario_keys: set[str] = set()
    scenario_case_counts: dict[str, int] = {}
    actual_scenario_keys_by_pair: dict[str, str] = {}
    for case_index, raw_case in enumerate(pair_interaction_cases):
        if not isinstance(raw_case, dict):
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] must be object")
            continue
        test_name = str(raw_case.get("test_name", "")).strip()
        scenario_key = str(raw_case.get("scenario_key", "")).strip()
        matchup_id = str(raw_case.get("matchup_id", "")).strip()
        character_ids = raw_case.get("character_ids", [])
        if not test_name:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] missing test_name")
        elif test_name in actual_test_names:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases duplicated test_name: {test_name}")
        else:
            actual_test_names.add(test_name)
        if not scenario_key:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] missing scenario_key")
        else:
            actual_scenario_keys.add(scenario_key)
            scenario_case_counts[scenario_key] = scenario_case_counts.get(scenario_key, 0) + 1
            if not (implemented_runner_methods & _runner_method_names(scenario_key)):
                ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] scenario_key has no runner in {scenario_registry_path}: {scenario_key}")
        if matchup_id not in derived_matchups:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] unknown matchup_id: {matchup_id}")
        if not isinstance(character_ids, list) or len(character_ids) != 2:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] must define exactly two character_ids")
            continue
        left_character_id = str(character_ids[0]).strip()
        right_character_id = str(character_ids[1]).strip()
        if left_character_id not in character_to_unit or right_character_id not in character_to_unit:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] references unknown formal character id")
            continue
        if not left_character_id or not right_character_id:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] contains empty character_ids")
            continue
        if left_character_id == right_character_id:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] cannot target the same character twice")
            continue
        if matchup_id in test_only_matchup_ids:
            ctx.failures.append(
                f"{matchup_catalog_path} pair_interaction_cases[{case_index}] must not reference test_only matchup_id: {matchup_id}"
            )
            continue
        expected_direction = matchup_direction_by_id.get(matchup_id)
        if expected_direction is not None and expected_direction != (left_character_id, right_character_id):
            ctx.failures.append(
                f"{matchup_catalog_path} pair_interaction_cases[{case_index}] character_ids must match matchup opener direction: {matchup_id}"
            )
            continue
        pair_key = _unordered_pair_key(left_character_id, right_character_id)
        actual_interaction_pairs.add(pair_key)
        if pair_key in actual_scenario_keys_by_pair and actual_scenario_keys_by_pair[pair_key] != scenario_key:
            ctx.failures.append(
                f"{matchup_catalog_path} pair_interaction_cases[{case_index}] must keep one scenario_key per unordered pair: {pair_key}"
            )
            continue
        actual_scenario_keys_by_pair[pair_key] = scenario_key
        case_signature = (left_character_id, right_character_id, matchup_id, scenario_key)
        if case_signature in actual_directional_cases:
            ctx.failures.append(
                f"{matchup_catalog_path} pair_interaction_cases duplicated directional case: {left_character_id}->{right_character_id}:{matchup_id}:{scenario_key}"
            )
            continue
        actual_directional_cases.add(case_signature)
    unreferenced_runner_methods = sorted(
        method_name
        for method_name in implemented_runner_methods
        if not any(method_name in _runner_method_names(scenario_key) for scenario_key in actual_scenario_keys)
    )
    if unreferenced_runner_methods:
        ctx.failures.append(
            f"{scenario_registry_path} contains unreferenced pair interaction runner methods: {', '.join(unreferenced_runner_methods)}"
        )
    missing_runner_scenarios = sorted(
        scenario_key
        for scenario_key in actual_scenario_keys
        if not (implemented_runner_methods & _runner_method_names(scenario_key))
    )
    if missing_runner_scenarios:
        ctx.failures.append(
            f"{matchup_catalog_path} contains interaction scenario_keys without runner methods: {', '.join(missing_runner_scenarios)}"
        )
    for scenario_key, case_count in sorted(scenario_case_counts.items()):
        if case_count != 2:
            ctx.failures.append(
                f"{matchup_catalog_path} pair_interaction_cases must derive exactly two directed cases for scenario_key: {scenario_key}"
            )
    missing_interaction_pairs = sorted(expected_interaction_pairs - actual_interaction_pairs)
    if missing_interaction_pairs:
        ctx.failures.append(f"{matchup_catalog_path} missing unordered pair_interaction coverage: {', '.join(missing_interaction_pairs)}")
    extra_interaction_pairs = sorted(actual_interaction_pairs - expected_interaction_pairs)
    if extra_interaction_pairs:
        ctx.failures.append(f"{matchup_catalog_path} contains non-matrix pair_interaction coverage: {', '.join(extra_interaction_pairs)}")

    missing_required_directional_cases = [
        f"{left}->{right}:{matchup_id}:{scenario_key}"
        for left, right, matchup_id, scenario_key in sorted(expected_directional_interaction_cases - actual_directional_cases)
    ]
    if missing_required_directional_cases:
        ctx.failures.append(
            f"{matchup_catalog_path} missing required directional pair_interaction cases: {', '.join(missing_required_directional_cases)}"
        )
    extra_directional_cases = [
        f"{left}->{right}:{matchup_id}:{scenario_key}"
        for left, right, matchup_id, scenario_key in sorted(actual_directional_cases - expected_directional_interaction_cases)
    ]
    if extra_directional_cases:
        ctx.failures.append(
            f"{matchup_catalog_path} contains non-matrix directional pair_interaction cases: {', '.join(extra_directional_cases)}"
        )
