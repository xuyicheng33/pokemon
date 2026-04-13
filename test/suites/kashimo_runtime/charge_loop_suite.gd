extends "res://test/suites/kashimo_runtime/base.gd"
const BaseSuiteScript := preload("res://test/suites/kashimo_runtime/base.gd")



func test_kashimo_raiken_negative_charge_contract() -> void:
	_assert_legacy_result(_test_kashimo_raiken_negative_charge_contract(_harness))

func test_kashimo_charge_positive_charge_contract() -> void:
	_assert_legacy_result(_test_kashimo_charge_positive_charge_contract(_harness))

func test_kashimo_feedback_strike_dynamic_power_and_clear_contract() -> void:
	_assert_legacy_result(_test_kashimo_feedback_strike_dynamic_power_and_clear_contract(_harness))
func _test_kashimo_raiken_negative_charge_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_setup = _support.build_kashimo_setup(sample_factory)
	battle_setup.sides[1].starting_index = 2
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, 801)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or target == null:
		return harness.fail_result("missing active units for raiken contract")
	var expected_tick: int = _support.calc_expected_fixed_effect_damage(core, content_index, "kashimo_negative_charge_mark", target)
	if expected_tick <= 0:
		return harness.fail_result("failed to resolve negative charge expected damage")
	for turn_index in range(1, 4):
		core.service("battle_logger").reset()
		core.service("turn_loop_controller").run_turn(battle_state, content_index, [
			_support.build_manual_skill_command(core, turn_index, "P1", "P1-A", "kashimo_raiken"),
			_support.build_manual_wait_command(core, turn_index, "P2", "P2-C"),
		])
		var stack_count: int = _support.count_effect_instances(target, "kashimo_negative_charge_mark")
		if stack_count != turn_index:
			return harness.fail_result("raiken should leave %d negative charge stacks after turn %d, actual=%d" % [turn_index, turn_index, stack_count])
		var tick_deltas: Array[int] = _support.collect_trigger_damage_deltas(core.service("battle_logger").event_log, target.unit_instance_id, "turn_end")
		if tick_deltas.size() != turn_index:
			return harness.fail_result("negative charge should emit %d turn_end ticks on turn %d, actual=%d" % [turn_index, turn_index, tick_deltas.size()])
		for tick_delta in tick_deltas:
			if tick_delta != expected_tick:
				return harness.fail_result("negative charge tick mismatch on turn %d: expected=%d actual=%d" % [turn_index, expected_tick, tick_delta])
	return harness.pass_result()

func _test_kashimo_charge_positive_charge_contract(harness) -> Dictionary:
	var state_payload = _build_kashimo_state(harness, 802)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var kashimo = battle_state.get_side("P1").get_active_unit()
	if kashimo == null:
		return harness.fail_result("missing kashimo active unit for charge contract")
	for turn_index in range(1, 4):
		core.service("turn_loop_controller").run_turn(battle_state, content_index, [
			_support.build_manual_skill_command(core, turn_index, "P1", "P1-A", "kashimo_charge"),
			_support.build_manual_wait_command(core, turn_index, "P2", "P2-A"),
		])
	if _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark") != 3:
		return harness.fail_result("charge should leave three positive charge stacks after three casts")
	var mp_before_turn_four: int = kashimo.current_mp
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 4, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 4, "P2", "P2-A"),
	])
	var plus_five_events: int = 0
	for event in core.service("battle_logger").event_log:
		if event.event_type != EventTypesScript.EFFECT_RESOURCE_MOD:
			continue
		if String(event.trigger_name) != "turn_start" or String(event.target_instance_id) != String(kashimo.unit_instance_id):
			continue
		if event.value_changes.is_empty():
			continue
		if int(event.value_changes[0].delta) == 5:
			plus_five_events += 1
	if plus_five_events != 3:
		return harness.fail_result("positive charge should emit exactly three +5 mp ticks on turn 4, actual=%d" % plus_five_events)
	if kashimo.current_mp - mp_before_turn_four != 25:
		return harness.fail_result("positive charge turn 4 total mp delta mismatch: expected=25 actual=%d" % (kashimo.current_mp - mp_before_turn_four))
	return harness.pass_result()

func _test_kashimo_feedback_strike_dynamic_power_and_clear_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_setup = _support.build_kashimo_setup(sample_factory)
	battle_setup.sides[1].starting_index = 2
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, 803)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or target == null:
		return harness.fail_result("missing active units for feedback strike contract")
	var positive_mark = content_index.effects.get("kashimo_positive_charge_mark", null)
	var negative_mark = content_index.effects.get("kashimo_negative_charge_mark", null)
	if positive_mark == null or negative_mark == null:
		return harness.fail_result("missing charge mark definitions for feedback strike contract")
	for _i in range(2):
		if core.service("effect_instance_service").create_instance(positive_mark, kashimo.unit_instance_id, battle_state, "test_feedback_positive", 0, kashimo.base_speed) == null:
			return harness.fail_result("failed to seed positive charges for feedback strike contract")
		if core.service("effect_instance_service").create_instance(negative_mark, target.unit_instance_id, battle_state, "test_feedback_negative", 0, kashimo.base_speed) == null:
			return harness.fail_result("failed to seed negative charges for feedback strike contract")
	if _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark") != 2:
		return harness.fail_result("feedback strike setup should leave two positive charges before cast")
	if _support.count_effect_instances(target, "kashimo_negative_charge_mark") != 2:
		return harness.fail_result("feedback strike setup should leave two negative charges before cast")
	var expected_power: int = 30 + 12 * 4
	var expected_damage: int = core.service("damage_service").apply_final_mod(
		core.service("damage_service").calc_base_damage(
			battle_state.battle_level,
			expected_power,
			kashimo.base_sp_attack,
			target.base_sp_defense
		),
		core.service("combat_type_service").calc_effectiveness("thunder", target.combat_type_ids)
	)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "kashimo_feedback_strike"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-C"),
	])
	var actual_damage: int = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	if actual_damage != expected_damage:
		return harness.fail_result("feedback strike damage mismatch: expected=%d actual=%d" % [expected_damage, actual_damage])
	if _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark") != 0:
		return harness.fail_result("feedback strike should clear all positive charges on hit")
	if _support.count_effect_instances(target, "kashimo_negative_charge_mark") != 0:
		return harness.fail_result("feedback strike should clear all negative charges on hit")
	return harness.pass_result()
