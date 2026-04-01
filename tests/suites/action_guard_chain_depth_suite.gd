extends RefCounted
class_name ActionGuardChainDepthSuite

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ActionGuardStateIntegrityTestSupportScript := preload("res://tests/support/action_guard_state_integrity_test_support.gd")

var _support = ActionGuardStateIntegrityTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("invalid_chain_depth_max_guard", failures, Callable(self, "_test_invalid_chain_depth_max_guard").bind(harness))
	runner.run_test("invalid_chain_depth_dedupe_guard", failures, Callable(self, "_test_invalid_chain_depth_dedupe_guard").bind(harness))
	runner.run_test("stacked_effect_instances_same_source_contract", failures, Callable(self, "_test_stacked_effect_instances_same_source_contract").bind(harness))

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
	var chain_context = _support.build_chain_context("test_depth_chain", p1_active.unit_instance_id, "")
	chain_context.command_type = CommandTypesScript.SKILL
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
	var p2_active = battle_state.get_side("P2").get_active_unit()
	var chain_context = _support.build_chain_context("test_dedupe_chain", p1_active.unit_instance_id, p2_active.unit_instance_id)
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
	var retriggered_effect_events = core.trigger_dispatcher.collect_events(
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
	if retriggered_effect_events.is_empty():
		return harness.fail_result("failed to rebuild dedupe guard effect event")
	if retriggered_effect_events[0].event_id == effect_events[0].event_id:
		return harness.fail_result("dedupe guard regression needs a fresh effect_event id")
	core.payload_executor.execute_effect_event(retriggered_effect_events[0], battle_state, content_index)
	if core.payload_executor.last_invalid_battle_code != ErrorCodesScript.INVALID_CHAIN_DEPTH:
		return harness.fail_result("expected invalid_chain_depth on dedupe guard, got %s" % str(core.payload_executor.last_invalid_battle_code))
	return harness.pass_result()

func _test_stacked_effect_instances_same_source_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1191)
	var stack_effect = EffectDefinitionScript.new()
	stack_effect.id = "test_same_source_stack_effect"
	stack_effect.display_name = "Same Source Stack Effect"
	stack_effect.scope = "self"
	stack_effect.stacking = "stack"
	stack_effect.trigger_names = PackedStringArray(["on_cast"])
	content_index.register_resource(stack_effect)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	core.effect_instance_service.create_instance(stack_effect, actor.unit_instance_id, battle_state, "same_stack_source", 1, actor.base_speed)
	core.effect_instance_service.create_instance(stack_effect, actor.unit_instance_id, battle_state, "same_stack_source", 1, actor.base_speed)
	battle_state.chain_context = _support.build_chain_context("test_same_source_stack_chain", actor.unit_instance_id, target.unit_instance_id)
	var effect_events = core.effect_instance_dispatcher.collect_trigger_events(
		"on_cast",
		battle_state,
		content_index,
		[actor.unit_instance_id],
		battle_state.chain_context
	)
	if effect_events.size() != 2:
		return harness.fail_result("expected two stacked effect events for same-source stack coverage")
	core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
	if core.payload_executor.last_invalid_battle_code != null:
		return harness.fail_result("first stacked effect event should pass, got %s" % str(core.payload_executor.last_invalid_battle_code))
	core.payload_executor.execute_effect_event(effect_events[1], battle_state, content_index)
	if core.payload_executor.last_invalid_battle_code != null:
		return harness.fail_result("second same-source stacked effect should not hit dedupe guard, got %s" % str(core.payload_executor.last_invalid_battle_code))
	return harness.pass_result()
