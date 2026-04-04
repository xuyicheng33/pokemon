extends RefCounted
class_name PayloadExecutionContractSuite

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const EffectPayloadScript := preload("res://src/battle_core/content/effect_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ActionGuardStateIntegrityTestSupportScript := preload("res://tests/support/action_guard_state_integrity_test_support.gd")

var _support = ActionGuardStateIntegrityTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("payload_handler_registry_completeness_contract", failures, Callable(self, "_test_payload_handler_registry_completeness_contract").bind(harness))
	runner.run_test("payload_executor_unknown_payload_fail_fast_contract", failures, Callable(self, "_test_payload_executor_unknown_payload_fail_fast_contract").bind(harness))
	runner.run_test("payload_executor_handler_missing_dependency_propagation_contract", failures, Callable(self, "_test_payload_executor_handler_missing_dependency_propagation_contract").bind(harness))

func _test_payload_handler_registry_completeness_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var registry = core.service("payload_handler_registry")
	if registry == null:
		return harness.fail_result("payload_handler_registry should be composed")
	var expected_paths := PackedStringArray([
		"res://src/battle_core/content/damage_payload.gd",
		"res://src/battle_core/content/heal_payload.gd",
		"res://src/battle_core/content/resource_mod_payload.gd",
		"res://src/battle_core/content/stat_mod_payload.gd",
		"res://src/battle_core/content/apply_field_payload.gd",
		"res://src/battle_core/content/apply_effect_payload.gd",
		"res://src/battle_core/content/remove_effect_payload.gd",
		"res://src/battle_core/content/rule_mod_payload.gd",
		"res://src/battle_core/content/forced_replace_payload.gd",
	])
	if registry.registered_payload_script_paths() != expected_paths:
		return harness.fail_result("payload handler registry drifted: expected=%s actual=%s" % [
			var_to_str(expected_paths),
			var_to_str(registry.registered_payload_script_paths()),
		])
	if not str(registry.resolve_missing_dependency()).is_empty():
		return harness.fail_result("payload handler registry should be dependency-complete, got %s" % str(registry.resolve_missing_dependency()))
	return harness.pass_result()

func _test_payload_executor_unknown_payload_fail_fast_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1317)

	var unknown_payload = EffectPayloadScript.new()
	unknown_payload.payload_type = "unknown"
	var unknown_effect = EffectDefinitionScript.new()
	unknown_effect.id = "test_unknown_payload_effect"
	unknown_effect.display_name = "Unknown Payload Effect"
	unknown_effect.scope = "self"
	unknown_effect.trigger_names = PackedStringArray(["on_cast"])
	unknown_effect.payloads.append(unknown_payload)
	content_index.register_resource(unknown_effect)

	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	battle_state.chain_context = _support.build_chain_context("test_unknown_payload_chain", actor.unit_instance_id, target.unit_instance_id)
	var effect_events = core.service("trigger_dispatcher").collect_events(
		"on_cast",
		battle_state,
		content_index,
		PackedStringArray([unknown_effect.id]),
		actor.unit_instance_id,
		"action_unknown_payload",
		2,
		actor.base_speed,
		battle_state.chain_context
	)
	if effect_events.is_empty():
		return harness.fail_result("failed to build unknown payload effect event")
	core.service("payload_executor").execute_effect_event(effect_events[0], battle_state, content_index)
	if core.service("payload_executor").last_invalid_battle_code != ErrorCodesScript.INVALID_EFFECT_DEFINITION:
		return harness.fail_result("unknown payload should fail-fast with invalid_effect_definition, got %s" % str(core.service("payload_executor").last_invalid_battle_code))
	return harness.pass_result()

func _test_payload_executor_handler_missing_dependency_propagation_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1318)

	core.service("payload_damage_runtime_service").faint_killer_attribution_service = null
	var expected_missing := "payload_handler_registry.payload_damage_handler.payload_damage_runtime_service.faint_killer_attribution_service"
	if core.service("payload_executor").resolve_missing_dependency() != expected_missing:
		return harness.fail_result("payload executor missing dependency path mismatch: expected=%s actual=%s" % [
			expected_missing,
			str(core.service("payload_executor").resolve_missing_dependency()),
		])

	var damage_payload = DamagePayloadScript.new()
	damage_payload.payload_type = "damage"
	damage_payload.amount = 15
	var damage_effect = EffectDefinitionScript.new()
	damage_effect.id = "test_payload_dependency_damage_effect"
	damage_effect.display_name = "Payload Dependency Damage Effect"
	damage_effect.scope = "target"
	damage_effect.trigger_names = PackedStringArray(["on_cast"])
	damage_effect.payloads.append(damage_payload)
	content_index.register_resource(damage_effect)

	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	battle_state.chain_context = _support.build_chain_context("test_payload_dependency_chain", actor.unit_instance_id, target.unit_instance_id)
	var effect_events = core.service("trigger_dispatcher").collect_events(
		"on_cast",
		battle_state,
		content_index,
		PackedStringArray([damage_effect.id]),
		actor.unit_instance_id,
		"action_payload_dependency",
		2,
		actor.base_speed,
		battle_state.chain_context
	)
	if effect_events.is_empty():
		return harness.fail_result("failed to build payload dependency effect event")
	core.service("payload_executor").execute_effect_event(effect_events[0], battle_state, content_index)
	if core.service("payload_executor").last_invalid_battle_code != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("payload executor should hard-stop on handler dependency drift, got %s" % str(core.service("payload_executor").last_invalid_battle_code))
	return harness.pass_result()
