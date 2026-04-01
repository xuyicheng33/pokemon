extends RefCounted
class_name GojoMiscRuntimeSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("gojo_reverse_ritual_heal_contract", failures, Callable(self, "_test_gojo_reverse_ritual_heal_contract").bind(harness))
	runner.run_test("gojo_plus5_competition_contract", failures, Callable(self, "_test_gojo_plus5_competition_contract").bind(harness))

func _test_gojo_reverse_ritual_heal_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var ritual_loadout: PackedStringArray = PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
	var battle_setup = sample_factory.build_gojo_vs_sample_setup({"P1": {0: ritual_loadout}})
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1216, battle_setup)
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	if gojo_unit == null:
		return harness.fail_result("missing gojo active unit")
	gojo_unit.current_hp = max(1, int(floor(float(gojo_unit.max_hp) * 0.5)))
	var before_hp: int = gojo_unit.current_hp
	var expected_gain: int = min(gojo_unit.max_hp - before_hp, max(1, int(floor(float(gojo_unit.max_hp) * 0.25))))
	core.battle_logger.reset()
	core.turn_loop_controller.run_turn(battle_state, content_index, [
		_support.build_skill_command(core, 1, "P1", "P1-A", "gojo_reverse_ritual"),
		_support.build_wait_command(core, 1, "P2", "P2-A"),
	])
	if gojo_unit.current_hp - before_hp != expected_gain:
		return harness.fail_result("反转术式应回复 25%% max_hp")
	return harness.pass_result()

func _test_gojo_plus5_competition_contract(harness) -> Dictionary:
	var state_payload = _support.build_gojo_battle_state(harness, 1217, true, true)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var sukuna_unit = battle_state.get_side("P2").get_active_unit()
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	sukuna_unit.base_speed = 999
	core.battle_logger.reset()
	core.turn_loop_controller.run_turn(battle_state, content_index, [
		_support.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_support.build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi"),
	])
	if not _support.has_event(core.battle_logger.event_log, func(ev):
		return ev.event_type == EventTypesScript.ACTION_CAST and ev.source_instance_id.find("action_") != -1 and ev.target_instance_id == gojo_unit.unit_instance_id
	):
		return harness.fail_result("同优先级 +5 且对手更快时，对手应先正常行动")
	if _support.has_event(core.battle_logger.event_log, func(ev):
		return ev.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START and ev.target_instance_id == sukuna_unit.unit_instance_id
	):
		return harness.fail_result("同优先级 +5 且对手先动时，Gojo 不应被误写成仍能首回合锁住对方")
	return harness.pass_result()
