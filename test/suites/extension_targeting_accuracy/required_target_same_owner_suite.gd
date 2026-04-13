extends "res://test/suites/extension_targeting_accuracy/base.gd"
const BaseSuiteScript := preload("res://test/suites/extension_targeting_accuracy/base.gd")



func test_required_target_same_owner_contract() -> void:
	_assert_legacy_result(_test_required_target_same_owner_contract(_harness))

func test_required_target_same_owner_missing_owner_contract() -> void:
	_assert_legacy_result(_test_required_target_same_owner_missing_owner_contract(_harness))
func _test_required_target_same_owner_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var marker_effect = EffectDefinitionScript.new()
	marker_effect.id = "test_required_same_owner_marker"
	marker_effect.display_name = "Required Same Owner Marker"
	marker_effect.scope = "self"
	marker_effect.duration_mode = "turns"
	marker_effect.duration = 2
	marker_effect.decrement_on = "turn_end"
	marker_effect.stacking = "replace"
	content_index.register_resource(marker_effect)

	var stat_payload = StatModPayloadScript.new()
	stat_payload.payload_type = "stat_mod"
	stat_payload.stat_name = "speed"
	stat_payload.stage_delta = -1
	var conditional_effect = EffectDefinitionScript.new()
	conditional_effect.id = "test_required_same_owner_effect"
	conditional_effect.display_name = "Required Same Owner Effect"
	conditional_effect.scope = "target"
	conditional_effect.trigger_names = PackedStringArray(["on_hit"])
	conditional_effect.required_target_effects = PackedStringArray([marker_effect.id])
	conditional_effect.required_target_same_owner = true
	conditional_effect.payloads.append(stat_payload)
	content_index.register_resource(conditional_effect)

	var conditional_skill = SkillDefinitionScript.new()
	conditional_skill.id = "test_required_same_owner_skill"
	conditional_skill.display_name = "Required Same Owner Skill"
	conditional_skill.damage_kind = "none"
	conditional_skill.power = 0
	conditional_skill.accuracy = 100
	conditional_skill.mp_cost = 0
	conditional_skill.priority = 0
	conditional_skill.targeting = "enemy_active_slot"
	conditional_skill.effects_on_hit_ids = PackedStringArray([conditional_effect.id])
	content_index.register_resource(conditional_skill)

	var mismatched_state = harness.build_initialized_battle(core, content_index, sample_factory, 910)
	var mismatched_p1 = mismatched_state.get_side("P1").get_active_unit()
	var mismatched_p2 = mismatched_state.get_side("P2").get_active_unit()
	mismatched_p1.regular_skill_ids[0] = conditional_skill.id
	mismatched_p1.base_speed = 999
	core.service("effect_instance_service").create_instance(
		marker_effect,
		mismatched_p2.unit_instance_id,
		mismatched_state,
		"test_required_same_owner_source",
		0,
		mismatched_p2.base_speed,
		EffectSourceMetaHelperScript.build_meta("other_owner")
	)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(mismatched_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": conditional_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if int(mismatched_p2.stat_stages.get("speed", 0)) != 0:
		return harness.fail_result("required_target_same_owner should skip payloads when marker source owner mismatches")

	var matched_state = harness.build_initialized_battle(core, content_index, sample_factory, 911)
	var matched_p1 = matched_state.get_side("P1").get_active_unit()
	var matched_p2 = matched_state.get_side("P2").get_active_unit()
	matched_p1.regular_skill_ids[0] = conditional_skill.id
	matched_p1.base_speed = 999
	core.service("effect_instance_service").create_instance(
		marker_effect,
		matched_p2.unit_instance_id,
		matched_state,
		"test_required_same_owner_source",
		0,
		matched_p2.base_speed,
		EffectSourceMetaHelperScript.build_meta(matched_p1.unit_instance_id)
	)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(matched_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": conditional_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if int(matched_p2.stat_stages.get("speed", 0)) != -1:
		return harness.fail_result("required_target_same_owner should allow payloads once marker source owner matches current effect owner")
	return harness.pass_result()

func _test_required_target_same_owner_missing_owner_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 912)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if actor == null or target == null:
		return harness.fail_result("missing active units for same-owner missing owner contract")

	var marker_effect = EffectDefinitionScript.new()
	marker_effect.id = "test_required_same_owner_missing_marker"
	marker_effect.display_name = "Required Same Owner Missing Marker"
	marker_effect.scope = "self"
	marker_effect.duration_mode = "turns"
	marker_effect.duration = 2
	marker_effect.decrement_on = "turn_end"
	marker_effect.stacking = "replace"
	content_index.register_resource(marker_effect)

	var conditional_effect = EffectDefinitionScript.new()
	conditional_effect.id = "test_required_same_owner_missing_effect"
	conditional_effect.display_name = "Required Same Owner Missing Effect"
	conditional_effect.scope = "target"
	conditional_effect.required_target_effects = PackedStringArray([marker_effect.id])
	conditional_effect.required_target_same_owner = true
	if core.service("effect_instance_service").create_instance(
		marker_effect,
		target.unit_instance_id,
		battle_state,
		"test_required_same_owner_missing_source",
		0,
		actor.base_speed
	) == null:
		return harness.fail_result("failed to seed same-owner marker without owner meta")

	var effect_event = EffectEventScript.new()
	effect_event.owner_id = actor.unit_instance_id
	var chain_context = ChainContextScript.new()
	chain_context.target_unit_id = target.unit_instance_id
	effect_event.chain_context = chain_context

	var precondition_service = core.service("effect_precondition_service")
	if precondition_service.passes_effect_preconditions(conditional_effect, effect_event, battle_state):
		return harness.fail_result("required_target_same_owner should not silently pass when marker owner meta is missing")
	if precondition_service.invalid_battle_code() != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("required_target_same_owner missing owner meta should report invalid_state_corruption")
	return harness.pass_result()
