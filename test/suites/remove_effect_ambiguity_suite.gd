extends "res://tests/support/gdunit_suite_bridge.gd"

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")


func test_remove_effect_ambiguity_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)

	var marker_effect = EffectDefinitionScript.new()
	marker_effect.id = "test_remove_marker"
	marker_effect.display_name = "Remove Marker"
	marker_effect.scope = "self"
	marker_effect.duration_mode = "turns"
	marker_effect.duration = 3
	marker_effect.decrement_on = "turn_end"
	marker_effect.stacking = "stack"
	content_index.register_resource(marker_effect)

	var apply_marker_a = ApplyEffectPayloadScript.new()
	apply_marker_a.payload_type = "apply_effect"
	apply_marker_a.effect_definition_id = marker_effect.id
	var apply_marker_b = ApplyEffectPayloadScript.new()
	apply_marker_b.payload_type = "apply_effect"
	apply_marker_b.effect_definition_id = marker_effect.id
	var double_apply_effect = EffectDefinitionScript.new()
	double_apply_effect.id = "test_double_apply_marker"
	double_apply_effect.display_name = "Double Apply Marker"
	double_apply_effect.scope = "target"
	double_apply_effect.trigger_names = PackedStringArray(["on_hit"])
	double_apply_effect.payloads.append(apply_marker_a)
	double_apply_effect.payloads.append(apply_marker_b)
	content_index.register_resource(double_apply_effect)

	var remove_marker_payload = RemoveEffectPayloadScript.new()
	remove_marker_payload.payload_type = "remove_effect"
	remove_marker_payload.effect_definition_id = marker_effect.id
	var remove_marker_effect = EffectDefinitionScript.new()
	remove_marker_effect.id = "test_remove_marker_effect"
	remove_marker_effect.display_name = "Remove Marker Effect"
	remove_marker_effect.scope = "target"
	remove_marker_effect.trigger_names = PackedStringArray(["on_hit"])
	remove_marker_effect.payloads.append(remove_marker_payload)
	content_index.register_resource(remove_marker_effect)

	var apply_skill = SkillDefinitionScript.new()
	apply_skill.id = "test_apply_double_marker_skill"
	apply_skill.display_name = "Apply Double Marker Skill"
	apply_skill.damage_kind = "none"
	apply_skill.power = 0
	apply_skill.accuracy = 100
	apply_skill.mp_cost = 0
	apply_skill.priority = 0
	apply_skill.targeting = "enemy_active_slot"
	apply_skill.effects_on_hit_ids = PackedStringArray([double_apply_effect.id])
	content_index.register_resource(apply_skill)

	var remove_skill = SkillDefinitionScript.new()
	remove_skill.id = "test_remove_marker_skill"
	remove_skill.display_name = "Remove Marker Skill"
	remove_skill.damage_kind = "none"
	remove_skill.power = 0
	remove_skill.accuracy = 100
	remove_skill.mp_cost = 0
	remove_skill.priority = 0
	remove_skill.targeting = "enemy_active_slot"
	remove_skill.effects_on_hit_ids = PackedStringArray([remove_marker_effect.id])
	content_index.register_resource(remove_skill)

	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 910)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	var p2_active = battle_state.get_side("P2").get_active_unit()
	if p1_active == null or p2_active == null:
		fail("missing active units for remove_effect ambiguity contract")
		return

	p1_active.regular_skill_ids[0] = apply_skill.id
	p1_active.base_speed = 999
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": apply_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])

	var marker_count := 0
	for effect_instance in p2_active.effect_instances:
		if effect_instance.def_id == marker_effect.id:
			marker_count += 1
	if marker_count != 2:
		fail("double apply marker skill should leave two marker instances before remove")
		return

	p1_active.regular_skill_ids[0] = remove_skill.id
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": remove_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_EFFECT_REMOVE_AMBIGUOUS:
		fail("remove_effect should hard fail on ambiguous stacked matches")
		return

