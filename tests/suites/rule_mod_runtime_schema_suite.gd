extends RefCounted
class_name RuleModRuntimeSchemaSuite

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

class MissingSchemaRuleModWriteService:
	extends "res://src/battle_core/effects/rule_mod_write_service.gd"

	func _resolve_stacking_key_schema(_mod_kind: String) -> Array:
		return []

class UnknownFieldRuleModWriteService:
	extends "res://src/battle_core/effects/rule_mod_write_service.gd"

	func _resolve_stacking_key_schema(_mod_kind: String) -> Array:
		return ["mod_kind", "mystery_field"]

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("rule_mod_missing_stacking_schema_fails_fast", failures, Callable(self, "_test_rule_mod_missing_stacking_schema_fails_fast").bind(harness))
	runner.run_test("rule_mod_unknown_stacking_key_field_fails_fast", failures, Callable(self, "_test_rule_mod_unknown_stacking_key_field_fails_fast").bind(harness))

func _test_rule_mod_missing_stacking_schema_fails_fast(harness) -> Dictionary:
	var service = MissingSchemaRuleModWriteService.new()
	return _assert_custom_stacking_schema_failure(
		harness,
		service,
		"Missing stacking key schema for rule_mod kind"
	)

func _test_rule_mod_unknown_stacking_key_field_fails_fast(harness) -> Dictionary:
	var service = UnknownFieldRuleModWriteService.new()
	return _assert_custom_stacking_schema_failure(
		harness,
		service,
		"Unknown stacking key field"
	)

func _assert_custom_stacking_schema_failure(harness, write_service, expected_message: String) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 118)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	if p1_active == null:
		return harness.fail_result("P1 active unit missing")

	var payload = RuleModPayloadScript.new()
	payload.payload_type = "rule_mod"
	payload.mod_kind = "final_mod"
	payload.mod_op = "mul"
	payload.value = 1.1
	payload.scope = "self"
	payload.duration_mode = "turns"
	payload.duration = 1
	payload.decrement_on = "turn_end"
	payload.stacking = "replace"
	payload.priority = 1
	write_service.id_factory = core.id_factory
	var created = write_service.create_instance(
		payload,
		{"scope": "unit", "id": p1_active.unit_instance_id},
		battle_state,
		"test_rule_mod_schema_fail",
		0,
		p1_active.base_speed
	)
	if created != null:
		return harness.fail_result("custom stacking schema failure should not create instance")
	if write_service.last_error_code != ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
		return harness.fail_result("custom stacking schema failure should report invalid_rule_mod_definition")
	if write_service.last_error_message.find(expected_message) == -1:
		return harness.fail_result("custom stacking schema failure missing expected message: %s" % expected_message)
	return harness.pass_result()
