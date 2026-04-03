extends RefCounted
class_name ContentSnapshotFormalCharacterRegistry

const REGISTRY_PATH := "res://src/battle_core/content/formal_character_validator_registry.json"
const CHARACTER_ID_KEY := "character_id"
const VALIDATOR_SCRIPT_PATH_KEY := "content_validator_script_path"

static func build_validator_instances() -> Dictionary:
    var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
    if file == null:
        return {
            "validators": [],
            "error": "ContentSnapshotFormalCharacterRegistry missing registry: %s" % REGISTRY_PATH,
        }
    var parsed = JSON.parse_string(file.get_as_text())
    if not (parsed is Array):
        return {
            "validators": [],
            "error": "ContentSnapshotFormalCharacterRegistry expects top-level array: %s" % REGISTRY_PATH,
        }
    var validators: Array = []
    var seen_character_ids: Dictionary = {}
    for raw_entry in parsed:
        if not (raw_entry is Dictionary):
            return {
                "validators": [],
                "error": "ContentSnapshotFormalCharacterRegistry expects dictionary entries",
            }
        var character_id := String(raw_entry.get(CHARACTER_ID_KEY, "")).strip_edges()
        if character_id.is_empty():
            return {
                "validators": [],
                "error": "ContentSnapshotFormalCharacterRegistry entry missing character_id",
            }
        if seen_character_ids.has(character_id):
            return {
                "validators": [],
                "error": "ContentSnapshotFormalCharacterRegistry duplicated character_id: %s" % character_id,
            }
        seen_character_ids[character_id] = true
        var validator_path := String(raw_entry.get(VALIDATOR_SCRIPT_PATH_KEY, "")).strip_edges()
        if validator_path.is_empty():
            return {
                "validators": [],
                "error": "ContentSnapshotFormalCharacterRegistry[%s] missing %s" % [character_id, VALIDATOR_SCRIPT_PATH_KEY],
            }
        var resolved_path := validator_path if validator_path.begins_with("res://") else "res://%s" % validator_path
        var validator_script = load(resolved_path)
        if validator_script == null:
            return {
                "validators": [],
                "error": "ContentSnapshotFormalCharacterRegistry[%s] failed to load validator: %s" % [character_id, validator_path],
            }
        var validator_instance = validator_script.new()
        if validator_instance == null:
            return {
                "validators": [],
                "error": "ContentSnapshotFormalCharacterRegistry[%s] failed to instantiate validator: %s" % [character_id, validator_path],
            }
        validators.append(validator_instance)
    return {
        "validators": validators,
        "error": "",
    }
