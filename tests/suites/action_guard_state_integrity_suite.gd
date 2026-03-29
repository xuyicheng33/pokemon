extends RefCounted
class_name ActionGuardStateIntegritySuite

const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("invalid_chain_depth_max_guard", failures, Callable(self, "_test_invalid_chain_depth_max_guard").bind(harness))
	runner.run_test("invalid_chain_depth_dedupe_guard", failures, Callable(self, "_test_invalid_chain_depth_dedupe_guard").bind(harness))
	runner.run_test("invalid_state_corruption_guard", failures, Callable(self, "_test_invalid_state_corruption_guard").bind(harness))
	runner.run_test("missing_chain_context_hard_fail", failures, Callable(self, "_test_missing_chain_context_hard_fail").bind(harness))
	runner.run_test("missing_core_dependency_hard_fail", failures, Callable(self, "_test_missing_core_dependency_hard_fail").bind(harness))

func _test_invalid_chain_depth_max_guard(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 118)

	var depth_guard_payload = StatModPayloadScript.new()
	depth_guard_payload.payload_type = "stat_mod"
	depth_guard_payload.stat_name = "attack"
	depth_guard_payload.stage_delta = 1
	var depth_guard_effect = EffectDefinitionScript.new()
	depth_guard_effect.id = "test_depth_guard_effect"
	depth_guard_effect.display_name = "Depth Guard Effect"
	depth_guard_effect.scope = "self"
	depth_guard_effect.trigger_names = PackedStringArray(["on_cast"])
	depth_guard_effect.payloads.clear()
	depth_guard_effect.payloads.append(depth_guard_payload)
	content_index.register_resource(depth_guard_effect)

	var p1_active = battle_state.get_side("P1").get_active_unit()
	var chain_context = ChainContextScript.new()
	chain_context.event_chain_id = "test_depth_chain"
	chain_context.chain_origin = "action"
	chain_context.command_type = CommandTypesScript.SKILL
	chain_context.command_source = "manual"
	chain_context.actor_id = p1_active.unit_instance_id
	chain_context.chain_depth = battle_state.max_chain_depth
	battle_state.chain_context = chain_context
	var effect_events = core.trigger_dispatcher.collect_events(
		"on_cast",
		battle_state,
		content_index,
		PackedStringArray([depth_guard_effect.id]),
		p1_active.unit_instance_id,
		"action_depth_guard",
		2,
		p1_active.base_speed,
		battle_state.chain_context
	)
	if effect_events.is_empty():
		return harness.fail_result("failed to build depth guard effect event")
	core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
	if core.payload_executor.last_invalid_battle_code != ErrorCodesScript.INVALID_CHAIN_DEPTH:
		return harness.fail_result("expected invalid_chain_depth on max depth guard, got %s" % str(core.payload_executor.last_invalid_battle_code))
	return harness.pass_result()

func _test_invalid_chain_depth_dedupe_guard(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 119)

	var dedupe_effect = EffectDefinitionScript.new()
	dedupe_effect.id = "test_dedupe_guard_effect"
	dedupe_effect.display_name = "Dedupe Guard Effect"
	dedupe_effect.scope = "self"
	dedupe_effect.trigger_names = PackedStringArray(["on_cast"])
	dedupe_effect.payloads.clear()
	content_index.register_resource(dedupe_effect)

	var p1_active = battle_state.get_side("P1").get_active_unit()
	var chain_context = ChainContextScript.new()
	chain_context.event_chain_id = "test_dedupe_chain"
	chain_context.chain_origin = "action"
	chain_context.command_type = CommandTypesScript.SKILL
	chain_context.command_source = "manual"
	chain_context.actor_id = p1_active.unit_instance_id
	chain_context.step_counter = 7
	battle_state.chain_context = chain_context
	var effect_events = core.trigger_dispatcher.collect_events(
		"on_cast",
		battle_state,
		content_index,
		PackedStringArray([dedupe_effect.id]),
		p1_active.unit_instance_id,
		"action_dedupe_guard",
		2,
		p1_active.base_speed,
		battle_state.chain_context
	)
	if effect_events.is_empty():
		return harness.fail_result("failed to build dedupe guard effect event")
	core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
	if core.payload_executor.last_invalid_battle_code != null:
		return harness.fail_result("first dedupe event should pass")
	battle_state.chain_context.step_counter = 7
	core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
	if core.payload_executor.last_invalid_battle_code != ErrorCodesScript.INVALID_CHAIN_DEPTH:
		return harness.fail_result("expected invalid_chain_depth on dedupe guard, got %s" % str(core.payload_executor.last_invalid_battle_code))
	return harness.pass_result()

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
	core.turn_loop_controller.run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		return harness.fail_result("state corruption should fail-fast")
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("expected invalid_state_corruption, got %s" % str(battle_state.battle_result.reason))
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

	core.turn_loop_controller.run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		return harness.fail_result("missing chain_context should fail-fast")
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("missing chain_context should map to invalid_state_corruption")
	for ev in core.battle_logger.event_log:
		if String(ev.event_chain_id) == "system:orphan":
			return harness.fail_result("system:orphan fallback should not exist")
	for ev in core.battle_logger.event_log:
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
	core.turn_resolution_service.effect_instance_dispatcher = null

	core.turn_loop_controller.run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		return harness.fail_result("missing core dependency should fail-fast")
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("missing dependency should map to invalid_state_corruption")
	for ev in core.battle_logger.event_log:
		if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_STATE_CORRUPTION:
			return harness.pass_result()
	return harness.fail_result("missing invalid_battle log for dependency hard-fail")
