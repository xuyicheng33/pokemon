extends RefCounted
class_name ObitoTestSupport

const DomainRoleTestSupportScript := preload("res://tests/support/domain_role_test_support.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var _support = DomainRoleTestSupportScript.new()

func build_obito_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
    var battle_setup = sample_factory.build_sample_setup({
        "P1": p1_regular_skill_overrides,
        "P2": p2_regular_skill_overrides,
    })
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["obito_juubi_jinchuriki", "sample_mossaur", "sample_pyron"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func build_obito_vs_gojo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
    var battle_setup = build_obito_setup(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides)
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func build_obito_mirror_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
    var battle_setup = sample_factory.build_sample_setup({
        "P1": p1_regular_skill_overrides,
        "P2": p2_regular_skill_overrides,
    })
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["obito_juubi_jinchuriki", "sample_mossaur", "sample_pyron"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["obito_juubi_jinchuriki", "sample_tidekit", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func build_battle_state(core, content_index, battle_setup, seed: int):
    return _support.build_battle_state(core, content_index, battle_setup, seed)

func build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_manual_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _support.build_manual_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return _support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func build_manual_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
    return _support.build_manual_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func find_unit_on_side(battle_state, side_id: String, definition_id: String):
    var side_state = battle_state.get_side(side_id)
    if side_state == null:
        return null
    for unit_state in side_state.team_units:
        if String(unit_state.definition_id) == definition_id:
            return unit_state
    return null

func count_effect_instances(unit_state, effect_id: String) -> int:
    var count := 0
    for effect_instance in unit_state.effect_instances:
        if String(effect_instance.def_id) == effect_id:
            count += 1
    return count

func find_rule_mod_instance(unit_state, mod_kind: String):
    for rule_mod_instance in unit_state.rule_mod_instances:
        if String(rule_mod_instance.mod_kind) == mod_kind:
            return rule_mod_instance
    return null

func count_rule_mod_instances(unit_state, mod_kind: String) -> int:
    var count := 0
    for rule_mod_instance in unit_state.rule_mod_instances:
        if String(rule_mod_instance.mod_kind) == mod_kind:
            count += 1
    return count

func collect_actor_damage_events(event_log: Array, actor_public_id: String) -> Array:
    var matched: Array = []
    for event in event_log:
        if String(event.event_type) != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(event.payload_summary).begins_with("%s dealt " % actor_public_id):
            matched.append(event)
    return matched

func collect_target_heal_events(event_log: Array, target_unit_id: String) -> Array:
    var matched: Array = []
    for event in event_log:
        if String(event.event_type) != EventTypesScript.EFFECT_HEAL:
            continue
        if String(event.target_instance_id) == target_unit_id:
            matched.append(event)
    return matched
