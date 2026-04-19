extends RefCounted
class_name ContentSnapshotFormalCharacterValidator

const FormalCharacterRegistryScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd")

var registry_path_override: String = ""
var _descriptors: Array = []
var _registry_error: String = ""
var _validator_cache: Dictionary = {}
var _validator_error_cache: Dictionary = {}
var _descriptors_loaded: bool = false

func validate(content_index: BattleContentIndex, errors: Array) -> void:
	_ensure_descriptors_loaded()
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
		var instantiate_result := _resolve_validator_result(descriptor)
		var instantiate_error := String(instantiate_result.get("error", ""))
		if not instantiate_error.is_empty():
			errors.append(instantiate_error)
			continue
		var validator = instantiate_result.get("validator", null)
		if validator == null:
			continue
		validator.validate(content_index, errors)

func _character_is_present(content_index: BattleContentIndex, descriptor: Dictionary) -> bool:
	var unit_definition_id := String(descriptor.get("unit_definition_id", "")).strip_edges()
	if unit_definition_id.is_empty():
		return false
	return content_index.units.has(unit_definition_id)

func _ensure_descriptors_loaded() -> void:
	if _descriptors_loaded:
		return
	_descriptors_loaded = true
	var registry_result: Dictionary
	if String(registry_path_override).strip_edges().is_empty():
		registry_result = FormalCharacterRegistryScript.build_validator_descriptors()
	else:
		registry_result = FormalCharacterRegistryScript.build_validator_descriptors_from_path(registry_path_override)
	_registry_error = String(registry_result.get("error", ""))
	_descriptors = registry_result.get("descriptors", [])

func _resolve_validator_result(descriptor: Dictionary) -> Dictionary:
	var cache_key := String(descriptor.get("unit_definition_id", "")).strip_edges()
	if cache_key.is_empty():
		cache_key = String(descriptor.get("character_id", "")).strip_edges()
	if _validator_error_cache.has(cache_key):
		return {
			"validator": null,
			"error": String(_validator_error_cache[cache_key]),
		}
	if _validator_cache.has(cache_key):
		return {
			"validator": _validator_cache[cache_key],
			"error": "",
		}
	var instantiate_result := FormalCharacterRegistryScript.instantiate_validator_descriptor(descriptor)
	var instantiate_error := String(instantiate_result.get("error", ""))
	if not instantiate_error.is_empty():
		_validator_error_cache[cache_key] = instantiate_error
		return {
			"validator": null,
			"error": instantiate_error,
		}
	var validator = instantiate_result.get("validator", null)
	if validator != null:
		_validator_cache[cache_key] = validator
	return {
		"validator": validator,
		"error": "",
	}
