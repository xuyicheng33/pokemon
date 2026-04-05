extends RefCounted
class_name ContentSnapshotFormalCharacterValidator

const FormalCharacterRegistryScript := preload("res://src/battle_core/content/content_snapshot_formal_character_registry.gd")

var _descriptors: Array = []
var _registry_error: String = ""

func _init() -> void:
	var registry_result: Dictionary = FormalCharacterRegistryScript.build_validator_descriptors()
	_registry_error = String(registry_result.get("error", ""))
	_descriptors = registry_result.get("descriptors", [])

func validate(content_index, errors: Array) -> void:
	if not _registry_error.is_empty():
		errors.append(_registry_error)
		return
	if content_index == null:
		return
	for raw_descriptor in _descriptors:
		if not (raw_descriptor is Dictionary):
			continue
		var descriptor: Dictionary = raw_descriptor
		if not _character_is_present(content_index, descriptor):
			continue
		var validator = descriptor.get("validator", null)
		if validator == null:
			continue
		validator.validate(content_index, errors)

func _character_is_present(content_index, descriptor: Dictionary) -> bool:
	var unit_definition_id := String(descriptor.get("unit_definition_id", "")).strip_edges()
	if unit_definition_id.is_empty():
		return false
	return content_index.units.has(unit_definition_id)
