from __future__ import annotations

import re


REQUIRED_DIRECTIONAL_INTERACTION_CASES = [
    ("gojo_satoru", "sukuna", "gojo_vs_sukuna", "gojo_vs_sukuna_domain_cleanup"),
    ("sukuna", "gojo_satoru", "sukuna_vs_gojo", "sukuna_vs_gojo_domain_cleanup"),
    ("gojo_satoru", "kashimo_hajime", "gojo_vs_kashimo", "gojo_vs_kashimo_kyokyo_nullify_domain_accuracy"),
    ("kashimo_hajime", "gojo_satoru", "kashimo_vs_gojo", "kashimo_vs_gojo_kyokyo_nullify_domain_accuracy"),
    ("gojo_satoru", "obito_juubi_jinchuriki", "gojo_vs_obito", "gojo_vs_obito_heal_block_public_contract"),
    ("obito_juubi_jinchuriki", "gojo_satoru", "obito_vs_gojo", "obito_vs_gojo_heal_block_public_contract"),
    ("sukuna", "kashimo_hajime", "sukuna_vs_kashimo", "sukuna_vs_kashimo_domain_accuracy_nullified"),
    ("kashimo_hajime", "sukuna", "kashimo_vs_sukuna", "kashimo_vs_sukuna_domain_accuracy_nullified"),
    ("sukuna", "obito_juubi_jinchuriki", "sukuna_vs_obito", "sukuna_vs_obito_field_seal_and_kamado_lifecycle"),
    ("obito_juubi_jinchuriki", "sukuna", "obito_vs_sukuna", "obito_vs_sukuna_field_seal_and_kamado_lifecycle"),
    ("kashimo_hajime", "obito_juubi_jinchuriki", "kashimo_vs_obito", "kashimo_vs_obito_yinyang_and_amber_persistence"),
    ("obito_juubi_jinchuriki", "kashimo_hajime", "obito_vs_kashimo", "obito_vs_kashimo_yinyang_and_amber_persistence"),
]


def _unordered_pair_key(left_character_id: str, right_character_id: str) -> str:
    return "<->".join(sorted([left_character_id, right_character_id]))


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
        _unordered_pair_key(runtime_character_ids[left_index], runtime_character_ids[right_index])
        for left_index in range(len(runtime_character_ids))
        for right_index in range(left_index + 1, len(runtime_character_ids))
    }
    actual_interaction_pairs: set[str] = set()
    actual_directional_cases: set[tuple[str, str, str, str]] = set()
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
        actual_interaction_pairs.add(_unordered_pair_key(left_character_id, right_character_id))
        actual_directional_cases.add((left_character_id, right_character_id, matchup_id, scenario_id))
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
        f"{left}->{right}:{matchup_id}:{scenario_id}"
        for left, right, matchup_id, scenario_id in REQUIRED_DIRECTIONAL_INTERACTION_CASES
        if (left, right, matchup_id, scenario_id) not in actual_directional_cases
    ]
    if missing_required_directional_cases:
        ctx.failures.append(
            f"{matchup_catalog_path} missing required directional pair_interaction cases: {', '.join(missing_required_directional_cases)}"
        )
