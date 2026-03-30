extends RefCounted
class_name SukunaTestSupport

const DomainRoleTestSupportScript := preload("res://tests/support/domain_role_test_support.gd")

var _domain_support = DomainRoleTestSupportScript.new()

func build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
    var battle_setup = sample_factory.build_sample_setup({"P1": p1_regular_skill_overrides})
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func build_battle_state(core, content_index, battle_setup, seed: int):
    return _domain_support.build_battle_state(core, content_index, battle_setup, seed)

func build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _domain_support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return _domain_support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func sum_unit_bst(unit_state) -> int:
    return _domain_support.sum_unit_bst(unit_state)

func resolve_matchup_gap_value(owner_total: int, opponent_total: int, thresholds: PackedInt32Array, outputs: PackedInt32Array, default_value: int) -> int:
    return _domain_support.resolve_matchup_gap_value(owner_total, opponent_total, thresholds, outputs, default_value)
