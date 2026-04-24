extends RefCounted
class_name ContentSnapshotFormalCharacterRegistry

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const ResourcePathHelperScript := preload("res://src/shared/resource_path_helper.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const REGISTRY_PATH := "res://config/formal_character_manifest.json"

static func load_entries() -> Dictionary:
	return load_entries_from_path(REGISTRY_PATH)

static func load_entries_from_path(registry_path: String) -> Dictionary:
	var manifest = FormalCharacterManifestScript.new()
	manifest.manifest_path_override = _resolve_registry_path(registry_path)
	var entries_result := manifest.build_runtime_entries_result()
	if bool(entries_result.get("ok", false)):
		return ResultEnvelopeHelperScript.ok(entries_result.get("data", []))
	return _error_result(String(entries_result.get("error_message", "unknown manifest error")))

static func build_validator_descriptors() -> Dictionary:
	return build_validator_descriptors_from_path(REGISTRY_PATH)

static func build_validator_descriptors_from_path(registry_path: String) -> Dictionary:
	var load_result := load_entries_from_path(registry_path)
	if not bool(load_result.get("ok", false)):
		return load_result
	var descriptors: Array = []
	for raw_entry in load_result.get("data", []):
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var validator_path := String(entry.get("content_validator_script_path", "")).strip_edges()
		if validator_path.is_empty():
			continue
		var resolved_validator_path := validator_path if validator_path.begins_with("res://") else "res://%s" % validator_path
		descriptors.append({
			"character_id": character_id,
			"unit_definition_id": String(entry.get("unit_definition_id", "")).strip_edges(),
			"content_validator_script_path": resolved_validator_path,
			"entry": entry.duplicate(true),
		})
	return ResultEnvelopeHelperScript.ok(descriptors)

static func instantiate_validator_descriptor(descriptor: Dictionary) -> Dictionary:
	var character_id := String(descriptor.get("character_id", "")).strip_edges()
	var validator_path := String(descriptor.get("content_validator_script_path", "")).strip_edges()
	if validator_path.is_empty():
		return _error_result("ContentSnapshotFormalCharacterRegistry[%s] missing validator path" % character_id)
	var validator_script = load(validator_path)
	if validator_script == null:
		return _error_result("ContentSnapshotFormalCharacterRegistry[%s] failed to load validator: %s" % [character_id, validator_path])
	if not (validator_script is Script) or not validator_script.can_instantiate():
		return _error_result("ContentSnapshotFormalCharacterRegistry[%s] validator is not instantiable" % character_id)
	var validator_instance = validator_script.new()
	if validator_instance == null or not validator_instance.has_method("validate"):
		return _error_result("ContentSnapshotFormalCharacterRegistry[%s] failed to instantiate validator" % character_id)
	return ResultEnvelopeHelperScript.ok(validator_instance)

static func build_validator_instances() -> Dictionary:
	return build_validator_instances_from_path(REGISTRY_PATH)

static func build_validator_instances_from_path(registry_path: String) -> Dictionary:
	var descriptor_result := build_validator_descriptors_from_path(registry_path)
	if not bool(descriptor_result.get("ok", false)):
		return descriptor_result
	var validators: Array = []
	for raw_descriptor in descriptor_result.get("data", []):
		if not (raw_descriptor is Dictionary):
			continue
		var instantiate_result := instantiate_validator_descriptor(raw_descriptor)
		if not bool(instantiate_result.get("ok", false)):
			return instantiate_result
		var validator = instantiate_result.get("data", null)
		if validator != null:
			validators.append(validator)
	return ResultEnvelopeHelperScript.ok(validators)

static func _error_result(error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(ErrorCodesScript.INVALID_BATTLE_SETUP, error_message)

static func _resolve_registry_path(registry_path: String) -> String:
	return ResourcePathHelperScript.resolve(registry_path, REGISTRY_PATH)
