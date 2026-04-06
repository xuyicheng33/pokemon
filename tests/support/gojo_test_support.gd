extends RefCounted
class_name GojoTestSupport

const EffectSourceMetaHelperScript := preload("res://src/battle_core/effects/effect_source_meta_helper.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const FormalCharacterTestSupportScript := preload("res://tests/support/formal_character_test_support.gd")

var _formal_support = FormalCharacterTestSupportScript.new()

func build_gojo_vs_sample_state(harness, seed: int) -> Dictionary:
	return build_gojo_battle_state(harness, seed, false, true)

func build_gojo_vs_sukuna_state(harness, seed: int) -> Dictionary:
	return build_gojo_battle_state(harness, seed, true, true)

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
	var matchup_id := ""
	if gojo_on_p1:
		matchup_id = "gojo_vs_sukuna" if use_sukuna else "gojo_vs_sample"
	else:
		matchup_id = "sukuna_vs_gojo" if use_sukuna else "sample_vs_gojo"
	var battle_setup = _formal_support.build_matchup_setup(sample_factory, matchup_id)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, seed, battle_setup)
	return {
		"core": core,
		"content_index": content_index,
		"battle_state": battle_state,
	}

func build_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _formal_support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _formal_support.build_manual_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
	return _formal_support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func build_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
	return _formal_support.build_manual_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

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
	var effect_meta := EffectSourceMetaHelperScript.build_meta(resolved_owner_id)
	core.service("effect_instance_service").create_instance(content_index.effects["gojo_ao_mark"], target_unit.unit_instance_id, battle_state, source_instance_id, 0, source_speed, effect_meta)
	core.service("effect_instance_service").create_instance(content_index.effects["gojo_aka_mark"], target_unit.unit_instance_id, battle_state, source_instance_id, 0, source_speed, effect_meta)

func set_field_state(battle_state, field_id: String, creator_id: String) -> void:
	var field_state = FieldStateScript.new()
	field_state.field_def_id = field_id
	field_state.instance_id = "test_field_%s" % field_id
	field_state.creator = creator_id
	battle_state.field_state = field_state

func find_unit_on_side(battle_state, side_id: String, definition_id: String):
	return _formal_support.find_unit_on_side(battle_state, side_id, definition_id)

func find_effect_instance(unit_state, effect_id: String):
	return _formal_support.find_effect_instance(unit_state, effect_id)

func count_effect_instances(unit_state, effect_id: String) -> int:
	return _formal_support.count_effect_instances(unit_state, effect_id)

func count_rule_mod_instances(unit_state, mod_kind: String) -> int:
	return _formal_support.count_rule_mod_instances(unit_state, mod_kind)

func count_target_damage_events(event_log: Array, event_type: String, target_unit_id: String) -> int:
	return _formal_support.count_target_damage_events(event_log, event_type, target_unit_id)

func has_event(event_log: Array, predicate: Callable) -> bool:
	return _formal_support.has_event(event_log, predicate)
