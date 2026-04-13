extends "res://test/support/gdunit_suite_bridge.gd"

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")



func test_skill_execute_runtime_contract() -> void:
	_assert_legacy_result(_test_skill_execute_runtime_contract(_harness))

func test_skill_execute_fallback_runtime_contract() -> void:
	_assert_legacy_result(_test_skill_execute_fallback_runtime_contract(_harness))

func test_skill_execute_validation_contract() -> void:
	_assert_legacy_result(_test_skill_execute_validation_contract(_harness))
func _test_skill_execute_runtime_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var execute_mark = _build_stack_mark_effect("test_execute_mark")
	content_index.register_resource(execute_mark)
	var execute_skill = _build_execute_skill("test_execute_skill", execute_mark.id)
	content_index.register_resource(execute_skill)
	content_index.units["sample_pyron"].skill_ids[0] = execute_skill.id

	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 830)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if actor == null or target == null:
		return harness.fail_result("missing active units for execute runtime contract")
	var before_hp: int = max(1, int(floor(float(target.max_hp) * 0.3)))
	target.current_hp = before_hp
	for _i in range(5):
		if core.service("effect_instance_service").create_instance(execute_mark, actor.unit_instance_id, battle_state, "test_execute_mark", 0, actor.base_speed) == null:
			return harness.fail_result("failed to seed execute mark stack")

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": actor.public_id,
			"skill_id": execute_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": target.public_id,
		}),
	])

	if int(target.current_hp) != 0:
		return harness.fail_result("execute contract should set target hp to 0")
	var damage_events: Array = _collect_actor_damage_events(core.service("battle_logger").event_log, actor.public_id)
	if damage_events.size() != 1:
		return harness.fail_result("execute contract should only emit one damage event")
	var damage_delta: int = abs(int(damage_events[0].value_changes[0].delta))
	if damage_delta != before_hp:
		return harness.fail_result("execute contract should log remaining hp as damage: expected=%d actual=%d" % [before_hp, damage_delta])
	if String(damage_events[0].payload_summary).find("[execute]") == -1:
		return harness.fail_result("execute damage log should carry execute marker")
	return harness.pass_result()

func _test_skill_execute_fallback_runtime_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var execute_mark = _build_stack_mark_effect("test_execute_mark_fallback")
	content_index.register_resource(execute_mark)
	var execute_skill = _build_execute_skill("test_execute_skill_fallback", execute_mark.id)
	content_index.register_resource(execute_skill)
	content_index.units["sample_pyron"].skill_ids[0] = execute_skill.id

	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 831)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if actor == null or target == null:
		return harness.fail_result("missing active units for execute fallback contract")
	var before_hp: int = int(target.current_hp)
	for _i in range(5):
		if core.service("effect_instance_service").create_instance(execute_mark, actor.unit_instance_id, battle_state, "test_execute_mark_fallback", 0, actor.base_speed) == null:
			return harness.fail_result("failed to seed execute fallback mark stack")

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": actor.public_id,
			"skill_id": execute_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": target.public_id,
		}),
	])

	var expected_damage: int = _calc_expected_damage(core, battle_state, actor, target, 24, "light")
	var actual_damage: int = before_hp - int(target.current_hp)
	if actual_damage != expected_damage:
		return harness.fail_result("execute fallback should use normal damage path: expected=%d actual=%d" % [expected_damage, actual_damage])
	if int(target.current_hp) <= 0:
		return harness.fail_result("execute fallback should not kill full-hp target")
	var damage_events: Array = _collect_actor_damage_events(core.service("battle_logger").event_log, actor.public_id)
	if damage_events.size() != 1 or String(damage_events[0].payload_summary).find("[execute]") != -1:
		return harness.fail_result("fallback damage path should not emit execute-tagged log")
	return harness.pass_result()

func _test_skill_execute_validation_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var bad_skill = SkillDefinitionScript.new()
	bad_skill.id = "test_bad_execute_skill"
	bad_skill.display_name = "Bad Execute Skill"
	bad_skill.damage_kind = "special"
	bad_skill.power = 20
	bad_skill.accuracy = 100
	bad_skill.mp_cost = 0
	bad_skill.priority = 0
	bad_skill.targeting = "enemy_active_slot"
	bad_skill.execute_target_hp_ratio_lte = 1.2
	bad_skill.execute_required_total_stacks = 3
	content_index.register_resource(bad_skill)

	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "skill[test_bad_execute_skill].execute_target_hp_ratio_lte out of range: 1.2"):
		return harness.fail_result("execute validation should reject ratio out of range")
	if not _has_error(errors, "skill[test_bad_execute_skill].execute_required_total_stacks requires execute effect ids"):
		return harness.fail_result("execute validation should reject missing execute effect ids")
	return harness.pass_result()

func _build_stack_mark_effect(effect_id: String):
	var effect = EffectDefinitionScript.new()
	effect.id = effect_id
	effect.display_name = effect_id
	effect.scope = "self"
	effect.duration_mode = "permanent"
	effect.stacking = "stack"
	effect.max_stacks = 8
	return effect

func _build_execute_skill(skill_id: String, mark_effect_id: String):
	var skill = SkillDefinitionScript.new()
	skill.id = skill_id
	skill.display_name = skill_id
	skill.damage_kind = "special"
	skill.power = 24
	skill.accuracy = 100
	skill.mp_cost = 0
	skill.priority = 0
	skill.targeting = "enemy_active_slot"
	skill.combat_type_id = "light"
	skill.execute_target_hp_ratio_lte = 0.3
	skill.execute_required_total_stacks = 5
	skill.execute_self_effect_ids = PackedStringArray([mark_effect_id])
	return skill

func _collect_actor_damage_events(event_log: Array, actor_public_id: String) -> Array:
	var matched: Array = []
	for log_event in event_log:
		if log_event.event_type != EventTypesScript.EFFECT_DAMAGE:
			continue
		if String(log_event.payload_summary).begins_with("%s dealt " % actor_public_id):
			matched.append(log_event)
	return matched

func _calc_expected_damage(core, battle_state, actor, target, power: int, combat_type_id: String) -> int:
	var type_effectiveness: float = core.service("combat_type_service").calc_effectiveness(combat_type_id, target.combat_type_ids)
	return core.service("damage_service").apply_final_mod(
		core.service("damage_service").calc_base_damage(
			battle_state.battle_level,
			power,
			actor.base_sp_attack,
			target.base_sp_defense
		),
		type_effectiveness
	)

func _has_error(errors: Array, expected_error: String) -> bool:
	for error_message in errors:
		if String(error_message) == expected_error:
			return true
	return false
