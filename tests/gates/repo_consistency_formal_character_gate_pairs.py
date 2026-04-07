from __future__ import annotations

import re


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
    actual_surface_pairs: set[str] = set()
    for matchup_id, raw_matchup in matchups.items():
        if not isinstance(raw_matchup, dict):
            continue
        p1_units = raw_matchup.get("p1_units", [])
        p2_units = raw_matchup.get("p2_units", [])
        if not isinstance(p1_units, list) or not p1_units or not isinstance(p2_units, list) or not p2_units:
            continue
        p1_character_id = next((character_id for character_id, unit_id in character_to_unit.items() if unit_id == str(p1_units[0]).strip()), "")
        p2_character_id = next((character_id for character_id, unit_id in character_to_unit.items() if unit_id == str(p2_units[0]).strip()), "")
        if not p1_character_id or not p2_character_id or p1_character_id == p2_character_id:
            continue
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
        "<->".join(sorted([runtime_character_ids[left_index], runtime_character_ids[right_index]]))
        for left_index in range(len(runtime_character_ids))
        for right_index in range(left_index + 1, len(runtime_character_ids))
    }
    actual_interaction_pairs: set[str] = set()
    scenario_registry_text = ctx.read_text(scenario_registry_path)
    registered_scenario_ids = set(re.findall(r'"([^"]+)": Callable', scenario_registry_text))
    actual_scenario_ids: set[str] = set()
    for case_index, raw_case in enumerate(pair_interaction_cases):
        if not isinstance(raw_case, dict):
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] must be object")
            continue
        scenario_id = str(raw_case.get("scenario_id", "")).strip()
        matchup_id = str(raw_case.get("matchup_id", "")).strip()
        character_ids = raw_case.get("character_ids", [])
        if not scenario_id:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] missing scenario_id")
        else:
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
        battle_seed = raw_case.get("battle_seed", None)
        if not isinstance(battle_seed, int) or battle_seed <= 0:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] missing positive integer battle_seed")
        if left_character_id not in character_to_unit or right_character_id not in character_to_unit:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] references unknown formal character id")
            continue
        if not left_character_id or not right_character_id:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] contains empty character_ids")
            continue
        if left_character_id == right_character_id:
            ctx.failures.append(f"{matchup_catalog_path} pair_interaction_cases[{case_index}] cannot target the same character twice")
            continue
        pair_key = "<->".join(sorted([left_character_id, right_character_id]))
        if pair_key in actual_interaction_pairs:
            ctx.failures.append(f"{matchup_catalog_path} duplicated unordered pair_interaction case: {pair_key}")
        actual_interaction_pairs.add(pair_key)
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
