extends "res://test/suites/content_validation_core/base.gd"

const ContentPayloadValidatorScript := preload("res://src/battle_core/content/content_payload_validator.gd")
const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")
const PayloadValidatorRegistryScript := preload("res://src/battle_core/content/payload_validator_registry.gd")


func test_content_payload_validator_registry_dispatch_contract() -> void:
	var payload_validator = ContentPayloadValidatorScript.new()
	var missing_validator_keys := payload_validator.missing_registered_validator_keys()
	if not missing_validator_keys.is_empty():
		fail(
			"ContentPayloadValidator missing registered dispatchers: %s" % ", ".join(missing_validator_keys)
		)
		return
	var stale_validator_keys := payload_validator.stale_registered_validator_keys()
	if not stale_validator_keys.is_empty():
		fail(
			"ContentPayloadValidator has stale validator registry keys: %s" % ", ".join(stale_validator_keys)
		)
		return
	var errors: Array = []
	var content_index = BattleContentIndexScript.new()
	var bad_damage_payload = DamagePayloadScript.new()
	bad_damage_payload.amount = 0
	payload_validator.validate_payload(errors, "dispatch_damage_effect", bad_damage_payload, content_index)
	if errors.is_empty():
		fail("ContentPayloadValidator dynamic dispatch did not execute registered damage validator")
		return
	var has_damage_error := false
	for error_msg in errors:
		if str(error_msg).find("damage amount must be > 0") != -1:
			has_damage_error = true
			break
	if not has_damage_error:
		fail("ContentPayloadValidator dynamic dispatch returned wrong damage validation error")
		return
	for raw_validator_key in PayloadContractRegistryScript.registered_validator_keys():
		var validator_key := String(raw_validator_key).strip_edges()
		if payload_validator.validator_for_key(validator_key) == null:
			fail("ContentPayloadValidator failed to resolve validator registry entry: %s" % validator_key)
			return
		if PayloadValidatorRegistryScript.validator_script_path_for_key(validator_key).is_empty():
			fail("PayloadValidatorRegistry missing script path for validator_key: %s" % validator_key)
			return
