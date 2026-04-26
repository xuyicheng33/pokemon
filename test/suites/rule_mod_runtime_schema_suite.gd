extends "res://tests/support/gdunit_suite_bridge.gd"

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


func test_rule_mod_missing_stacking_schema_fails_fast() -> void:
	_run_custom_stacking_schema_failure(
		MissingSchemaRuleModWriteService.new(),
		"Missing stacking key schema for rule_mod kind"
	)

func test_rule_mod_unknown_stacking_key_field_fails_fast() -> void:
	_run_custom_stacking_schema_failure(
		UnknownFieldRuleModWriteService.new(),
		"Unknown stacking key field"
	)

func _run_custom_stacking_schema_failure(write_service, expected_message: String) -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 118)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	if p1_active == null:
		fail("P1 active unit missing")
		return

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
	write_service.id_factory = core.service("id_factory")
	var created = write_service.create_instance(
		payload,
		{"scope": "unit", "id": p1_active.unit_instance_id},
		battle_state,
		"test_rule_mod_schema_fail",
		0,
		p1_active.base_speed
	)
	if created != null:
		fail("custom stacking schema failure should not create instance")
		return
	if write_service.last_error_code != ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
		fail("custom stacking schema failure should report invalid_rule_mod_definition")
		return
	if write_service.last_error_message.find(expected_message) == -1:
		fail("custom stacking schema failure missing expected message: %s" % expected_message)
		return
