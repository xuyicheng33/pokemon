extends "res://tests/support/formal_character_test_support.gd"
class_name GojoTestSupport

const EffectSourceMetaHelperScript := preload("res://src/battle_core/effects/effect_source_meta_helper.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")

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
	var matchup_id := ""
	if gojo_on_p1:
		matchup_id = "gojo_vs_sukuna" if use_sukuna else "gojo_vs_sample"
	else:
		matchup_id = "sukuna_vs_gojo" if use_sukuna else "sample_vs_gojo"
	var battle_setup_result = build_matchup_setup_result(sample_factory, matchup_id)
	if not bool(battle_setup_result.get("ok", false)):
		return {"error": str(battle_setup_result.get("error_message", "failed to build gojo matchup setup"))}
	var battle_setup = battle_setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, seed, battle_setup)
	return {
		"core": core,
		"content_index": content_index,
		"battle_state": battle_state,
	}

func build_resolved_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, actor_id: String, skill_id: String):
	var command = build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)
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
