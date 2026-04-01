extends RefCounted
class_name GojoTestSupport

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const DomainRoleTestSupportScript := preload("res://tests/support/domain_role_test_support.gd")

var _domain_support = DomainRoleTestSupportScript.new()

func build_gojo_vs_sample_state(harness, seed: int) -> Dictionary:
    return build_gojo_battle_state(harness, seed, false, true)

func build_sample_vs_gojo_state(harness, seed: int, use_sukuna: bool) -> Dictionary:
    return build_gojo_battle_state(harness, seed, use_sukuna, false)

func build_gojo_battle_state(harness, seed: int, use_sukuna: bool, gojo_on_p1: bool) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return {"error": str(core_payload["error"])}
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return {"error": "SampleBattleFactory init failed"}
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = sample_factory.build_sample_setup()
    if use_sukuna:
        battle_setup.sides[0].unit_definition_ids = PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_pyron"]) if gojo_on_p1 else PackedStringArray(["sukuna", "sample_tidekit", "sample_mossaur"])
        battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sukuna", "sample_tidekit", "sample_mossaur"]) if gojo_on_p1 else PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"])
    else:
        battle_setup.sides[0].unit_definition_ids = PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"]) if gojo_on_p1 else PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"])
        battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"]) if gojo_on_p1 else PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].starting_index = 0
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, seed, battle_setup)
    return {
        "core": core,
        "content_index": content_index,
        "battle_state": battle_state,
    }

func build_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _domain_support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _domain_support.build_manual_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return _domain_support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func build_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
    return _domain_support.build_manual_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func build_resolved_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, actor_id: String, skill_id: String):
    var command = build_skill_command(core, turn_index, side_id, actor_public_id, skill_id)
    command.actor_id = actor_id
    return command

func build_accuracy_skill(skill_id: String, accuracy: int):
    var skill = SkillDefinitionScript.new()
    skill.id = skill_id
    skill.display_name = skill_id
    skill.damage_kind = "none"
    skill.power = 0
    skill.accuracy = accuracy
    skill.mp_cost = 0
    skill.priority = 0
    skill.targeting = "enemy_active_slot"
    return skill

func apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id: String, source_speed: int, source_owner_id: String = "") -> void:
    var resolved_owner_id := source_owner_id if not source_owner_id.is_empty() else source_instance_id
    var effect_meta := {
        "source_owner_id": resolved_owner_id,
    }
    core.effect_instance_service.create_instance(content_index.effects["gojo_ao_mark"], target_unit.unit_instance_id, battle_state, source_instance_id, 0, source_speed, effect_meta)
    core.effect_instance_service.create_instance(content_index.effects["gojo_aka_mark"], target_unit.unit_instance_id, battle_state, source_instance_id, 0, source_speed, effect_meta)

func set_field_state(battle_state, field_id: String, creator_id: String) -> void:
    var field_state = FieldStateScript.new()
    field_state.field_def_id = field_id
    field_state.instance_id = "test_field_%s" % field_id
    field_state.creator = creator_id
    battle_state.field_state = field_state

func find_unit_on_side(battle_state, side_id: String, definition_id: String):
    var side_state = battle_state.get_side(side_id)
    if side_state == null:
        return null
    for unit_state in side_state.team_units:
        if unit_state.definition_id == definition_id:
            return unit_state
    return null

func find_effect_instance(unit_state, effect_id: String):
    for effect_instance in unit_state.effect_instances:
        if effect_instance.def_id == effect_id:
            return effect_instance
    return null

func count_effect_instances(unit_state, effect_id: String) -> int:
    var count := 0
    for effect_instance in unit_state.effect_instances:
        if effect_instance.def_id == effect_id:
            count += 1
    return count

func count_rule_mod_instances(unit_state, mod_kind: String) -> int:
    var count := 0
    for rule_mod_instance in unit_state.rule_mod_instances:
        if rule_mod_instance.mod_kind == mod_kind:
            count += 1
    return count

func count_target_damage_events(event_log: Array, event_type: String, target_unit_id: String) -> int:
    var count := 0
    for ev in event_log:
        if ev.event_type == event_type and ev.target_instance_id == target_unit_id:
            count += 1
    return count

func has_event(event_log: Array, predicate: Callable) -> bool:
    for ev in event_log:
        if bool(predicate.call(ev)):
            return true
    return false
