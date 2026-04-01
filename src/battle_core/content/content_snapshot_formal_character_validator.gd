extends RefCounted
class_name ContentSnapshotFormalCharacterValidator

const FormalCharacterRegistryScript := preload("res://src/battle_core/content/content_snapshot_formal_character_registry.gd")

var _validators: Array = []
var _registry_error: String = ""

func _init() -> void:
    var registry_result: Dictionary = FormalCharacterRegistryScript.build_validator_instances()
    _registry_error = String(registry_result.get("error", ""))
    _validators = registry_result.get("validators", [])

func validate(content_index, errors: Array) -> void:
    if not _registry_error.is_empty():
        errors.append(_registry_error)
        return
    for validator in _validators:
        if validator == null:
            continue
        validator.validate(content_index, errors)
