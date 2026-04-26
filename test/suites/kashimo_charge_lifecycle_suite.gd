extends "res://tests/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _support = KashimoTestSupportScript.new()


func test_kashimo_negative_charge_overflow_and_roll_contract() -> void:
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
	content_index.units["sample_mossaur"].base_hp = 999
	var battle_setup = _support.build_kashimo_setup(sample_factory)
	battle_setup.sides[1].starting_index = 2
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, 841)
	var target = battle_state.get_side("P2").get_active_unit()
	if target == null:
		fail("missing target unit for negative charge lifecycle contract")
		return
	var target_public_id := String(target.public_id)
	var expected_tick = _support.calc_expected_fixed_effect_damage(core, content_index, "kashimo_negative_charge_mark", target)
	if expected_tick <= 0:
		fail("failed to resolve expected negative charge tick damage")
		return
	var expected_stacks_by_turn := {1: 1, 2: 2, 3: 3, 4: 2}
	var expected_tick_counts_by_turn := {1: 1, 2: 2, 3: 3, 4: 3}
	for turn_index in range(1, 5):
		core.service("battle_logger").reset()
		core.service("turn_loop_controller").run_turn(battle_state, content_index, [
			_support.build_manual_skill_command(core, turn_index, "P1", "P1-A", "kashimo_raiken"),
			_support.build_manual_wait_command(core, turn_index, "P2", target_public_id),
		])
		var stack_count = _support.count_effect_instances(target, "kashimo_negative_charge_mark")
		if stack_count != int(expected_stacks_by_turn[turn_index]):
			fail("negative charge stack count mismatch on turn %d: expected=%d actual=%d" % [
				turn_index,
				int(expected_stacks_by_turn[turn_index]),
				stack_count,
			])
			return
		var tick_deltas := _support.collect_trigger_damage_deltas(core.service("battle_logger").event_log, target.unit_instance_id, "turn_end")
		if tick_deltas.size() != int(expected_tick_counts_by_turn[turn_index]):
			fail("negative charge tick count mismatch on turn %d: expected=%d actual=%d" % [
				turn_index,
				int(expected_tick_counts_by_turn[turn_index]),
				tick_deltas.size(),
			])
			return
		for tick_delta in tick_deltas:
			if tick_delta != expected_tick:
				fail("negative charge tick damage mismatch on turn %d: expected=%d actual=%d" % [
					turn_index,
					expected_tick,
					tick_delta,
				])
				return

func test_kashimo_positive_charge_overflow_and_switch_clear_contract() -> void:
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
	var battle_state = _support.build_battle_state(core, content_index, _support.build_kashimo_setup(sample_factory), 842)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	if kashimo == null:
		fail("missing kashimo active unit for positive charge lifecycle contract")
		return
	for turn_index in range(1, 4):
		core.service("turn_loop_controller").run_turn(battle_state, content_index, [
			_support.build_manual_skill_command(core, turn_index, "P1", "P1-A", "kashimo_charge"),
			_support.build_manual_wait_command(core, turn_index, "P2", "P2-A"),
		])
	if _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark") != 3:
		fail("positive charge should reach exactly three stacks after three casts")
		return
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 4, "P1", "P1-A", "kashimo_charge"),
		_support.build_manual_wait_command(core, 4, "P2", "P2-A"),
	])
	if _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark") != 2:
		fail("positive charge overflow cast should not create a fourth stack and oldest stack should roll off after turn_end")
		return
	var turn_start_ticks = _count_resource_mod_ticks(core.service("battle_logger").event_log, kashimo.unit_instance_id, "turn_start", 5)
	if turn_start_ticks != 3:
		fail("positive charge overflow turn should still emit exactly three +5 turn_start ticks, actual=%d" % turn_start_ticks)
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_switch_command(core, 5, "P1", "P1-A", "P1-B"),
		_support.build_manual_wait_command(core, 5, "P2", "P2-A"),
	])
	if _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark") != 0:
		fail("positive charges should clear when kashimo leaves active slot")
		return

func test_kashimo_negative_charge_switch_clear_contract() -> void:
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
	content_index.units["sample_mossaur"].base_hp = 999
	var battle_setup = _support.build_kashimo_setup(sample_factory)
	battle_setup.sides[1].starting_index = 2
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, 843)
	var target = battle_state.get_side("P2").get_active_unit()
	if target == null:
		fail("missing target unit for negative charge switch clear contract")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "kashimo_raiken"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-C"),
	])
	if _support.count_effect_instances(target, "kashimo_negative_charge_mark") != 1:
		fail("negative charge setup should leave one stack before target switches")
		return
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 2, "P1", "P1-A"),
		_support.build_manual_switch_command(core, 2, "P2", "P2-C", "P2-A"),
	])
	var replacement = battle_state.get_side("P2").get_active_unit()
	if replacement == null or String(replacement.public_id) != "P2-A":
		fail("negative charge switch clear contract should bring in the requested replacement")
		return
	if _support.count_effect_instances(target, "kashimo_negative_charge_mark") != 0:
		fail("negative charges should clear when the marked target leaves active slot")
		return
	if _support.count_effect_instances(replacement, "kashimo_negative_charge_mark") != 0:
		fail("negative charges should not leak onto the replacement target")
		return
	var switch_turn_ticks := _support.collect_trigger_damage_deltas(core.service("battle_logger").event_log, target.unit_instance_id, "turn_end")
	if not switch_turn_ticks.is_empty():
		fail("negative charges should not keep ticking on the bench after switch clear")
		return


func _count_resource_mod_ticks(event_log: Array, target_instance_id: String, trigger_name: String, expected_delta: int) -> int:
	var count := 0
	for event in event_log:
		if event.event_type != EventTypesScript.EFFECT_RESOURCE_MOD:
			continue
		if String(event.target_instance_id) != target_instance_id:
			continue
		if String(event.trigger_name) != trigger_name:
			continue
		if event.value_changes.is_empty():
			continue
		if int(event.value_changes[0].delta) != expected_delta:
			continue
		count += 1
	return count
