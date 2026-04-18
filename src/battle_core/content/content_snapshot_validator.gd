extends RefCounted
class_name ContentSnapshotValidator

const ContentPayloadValidatorScript := preload("res://src/battle_core/content/content_payload_validator.gd")
const ContentSnapshotShapeValidatorScript := preload("res://src/battle_core/content/content_snapshot_shape_validator.gd")
const ContentSnapshotTriggerContractValidatorScript := preload("res://src/battle_core/content/content_snapshot_trigger_contract_validator.gd")

var _payload_validator = ContentPayloadValidatorScript.new()
var _shape_validator = ContentSnapshotShapeValidatorScript.new()
var _trigger_contract_validator = ContentSnapshotTriggerContractValidatorScript.new()

func validate(content_index) -> Array:
	var errors: Array = content_index.duplicate_registration_errors.duplicate()
	_shape_validator.validate(content_index, errors, _payload_validator)
	_trigger_contract_validator.validate(content_index, errors)
	return errors
