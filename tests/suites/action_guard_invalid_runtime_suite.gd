extends RefCounted
class_name ActionGuardInvalidRuntimeSuite

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("invalid_state_corruption_guard", failures, Callable(self, "_test_invalid_state_corruption_guard").bind(harness))
	runner.run_test("missing_active_slot_with_available_unit_guard", failures, Callable(self, "_test_missing_active_slot_with_available_unit_guard").bind(harness))
	runner.run_test("missing_chain_context_hard_fail", failures, Callable(self, "_test_missing_chain_context_hard_fail").bind(harness))
	runner.run_test("missing_core_dependency_hard_fail", failures, Callable(self, "_test_missing_core_dependency_hard_fail").bind(harness))

func _test_invalid_state_corruption_guard(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 120)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	p1_active.current_hp = p1_active.max_hp + 1
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		return harness.fail_result("state corruption should fail-fast")
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("expected invalid_state_corruption, got %s" % str(battle_state.battle_result.reason))
	return harness.pass_result()

func _test_missing_active_slot_with_available_unit_guard(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1201)
	battle_state.get_side("P1").clear_active_unit()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		return harness.fail_result("missing active slot with living units should fail-fast")
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("missing active slot should map to invalid_state_corruption")
	return harness.pass_result()

func _test_missing_chain_context_hard_fail(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 222)
	battle_state.chain_context = null

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		return harness.fail_result("missing chain_context should fail-fast")
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("missing chain_context should map to invalid_state_corruption")
	for ev in core.service("battle_logger").event_log:
		if String(ev.event_chain_id) == "system:orphan":
			return harness.fail_result("system:orphan fallback should not exist")
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_STATE_CORRUPTION:
			return harness.pass_result()
	return harness.fail_result("missing invalid_battle log for missing chain_context")

func _test_missing_core_dependency_hard_fail(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 223)
	core.service("turn_resolution_service").effect_instance_dispatcher = null

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		return harness.fail_result("missing core dependency should fail-fast")
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("missing dependency should map to invalid_state_corruption")
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_STATE_CORRUPTION:
			return harness.pass_result()
	return harness.fail_result("missing invalid_battle log for dependency hard-fail")
