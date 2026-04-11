extends "res://tests/suites/content_validation_core/base.gd"

const ContentPayloadValidatorScript := preload("res://src/battle_core/content/content_payload_validator.gd")
const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test(
		"content_payload_validator_registry_dispatch_contract",
		failures,
		Callable(self, "_test_content_payload_validator_registry_dispatch_contract").bind(harness)
	)

func _test_content_payload_validator_registry_dispatch_contract(harness) -> Dictionary:
	var payload_validator = ContentPayloadValidatorScript.new()
	var missing_validator_keys := payload_validator.missing_registered_validator_keys()
	if not missing_validator_keys.is_empty():
		return harness.fail_result(
			"ContentPayloadValidator missing registered dispatchers: %s" % ", ".join(missing_validator_keys)
		)
	var errors: Array = []
	var content_index = BattleContentIndexScript.new()
	var bad_damage_payload = DamagePayloadScript.new()
	bad_damage_payload.amount = 0
	payload_validator.validate_payload(errors, "dispatch_damage_effect", bad_damage_payload, content_index)
	if errors.is_empty():
		return harness.fail_result("ContentPayloadValidator dynamic dispatch did not execute registered damage validator")
	var has_damage_error := false
	for error_msg in errors:
		if str(error_msg).find("damage amount must be > 0") != -1:
			has_damage_error = true
			break
	if not has_damage_error:
		return harness.fail_result("ContentPayloadValidator dynamic dispatch returned wrong damage validation error")
	for raw_validator_key in PayloadContractRegistryScript.registered_validator_keys():
		var validator_key := String(raw_validator_key).strip_edges()
		var method_name := ContentPayloadValidatorScript.validator_method_name_for_key(validator_key)
		if method_name.is_empty():
			return harness.fail_result("ContentPayloadValidator produced empty method name for validator_key: %s" % validator_key)
	return harness.pass_result()
