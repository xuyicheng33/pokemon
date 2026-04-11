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


def validate_pair_catalog(
    ctx,
    *,
    runtime_character_ids: list[str],
    delivery_registry: list[dict],
    character_to_unit: dict[str, str],
    matchups: dict,
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
    expected_directional_interaction_cases: set[tuple[str, str, str]] = set()
    test_only_matchup_ids: set[str] = set()
    actual_surface_pairs: set[str] = set()
    for matchup_id, raw_matchup in matchups.items():
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
        expected_directional_interaction_cases.add((p1_character_id, p2_character_id, normalized_matchup_id))
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
    actual_interaction_pairs: set[str] = set()
    actual_directional_cases: set[tuple[str, str, str]] = set()
    actual_test_names: set[str] = set()
    scenario_registry_text = ctx.read_text(scenario_registry_path)
    registered_scenario_ids = set(re.findall(r'"([^"]+)": Callable', scenario_registry_text))
    actual_scenario_ids: set[str] = set()
    for case_index, raw_case in enumerate(pair_interaction_cases):
        if not isinstance(raw_case, dict):
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] must be object")
            continue
        test_name = str(raw_case.get("test_name", "")).strip()
        scenario_id = str(raw_case.get("scenario_id", "")).strip()
        matchup_id = str(raw_case.get("matchup_id", "")).strip()
        character_ids = raw_case.get("character_ids", [])
        if not test_name:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] missing test_name")
        elif test_name in actual_test_names:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases duplicated test_name: {test_name}")
        else:
            actual_test_names.add(test_name)
        if not scenario_id:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] missing scenario_id")
        else:
            if scenario_id in actual_scenario_ids:
                ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases duplicated scenario_id: {scenario_id}")
            actual_scenario_ids.add(scenario_id)
            if scenario_id not in registered_scenario_ids:
                ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] scenario_id not registered in {scenario_registry_path}: {scenario_id}")
        if matchup_id not in matchups:
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
        actual_interaction_pairs.add(_unordered_pair_key(left_character_id, right_character_id))
        actual_directional_cases.add((left_character_id, right_character_id, matchup_id))
    missing_registered_scenarios = sorted(registered_scenario_ids - actual_scenario_ids)
    if missing_registered_scenarios:
        ctx.failures.append(
            f"{scenario_registry_path} contains unreferenced scenario registrations: {', '.join(missing_registered_scenarios)}"
        )
    extra_registered_scenarios = sorted(actual_scenario_ids - registered_scenario_ids)
    if extra_registered_scenarios:
        ctx.failures.append(
            f"{matchup_catalog_path} contains unregistered interaction scenario_ids: {', '.join(extra_registered_scenarios)}"
        )
    missing_interaction_pairs = sorted(expected_interaction_pairs - actual_interaction_pairs)
    if missing_interaction_pairs:
        ctx.failures.append(f"{matchup_catalog_path} missing unordered pair_interaction coverage: {', '.join(missing_interaction_pairs)}")
    extra_interaction_pairs = sorted(actual_interaction_pairs - expected_interaction_pairs)
    if extra_interaction_pairs:
        ctx.failures.append(f"{matchup_catalog_path} contains non-matrix pair_interaction coverage: {', '.join(extra_interaction_pairs)}")

    missing_required_directional_cases = [
        f"{left}->{right}:{matchup_id}"
        for left, right, matchup_id in sorted(expected_directional_interaction_cases - actual_directional_cases)
    ]
    if missing_required_directional_cases:
        ctx.failures.append(
            f"{matchup_catalog_path} missing required directional pair_interaction cases: {', '.join(missing_required_directional_cases)}"
        )
    extra_directional_cases = [
        f"{left}->{right}:{matchup_id}"
        for left, right, matchup_id in sorted(actual_directional_cases - expected_directional_interaction_cases)
    ]
    if extra_directional_cases:
        ctx.failures.append(
            f"{matchup_catalog_path} contains non-matrix directional pair_interaction cases: {', '.join(extra_directional_cases)}"
        )
