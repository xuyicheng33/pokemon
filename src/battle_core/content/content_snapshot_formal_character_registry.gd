extends RefCounted
class_name ContentSnapshotFormalCharacterRegistry

const REGISTRY_PATH := "res://docs/records/formal_character_registry.json"
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
    for raw_entry in parsed:
        if not (raw_entry is Dictionary):
            return {
                "validators": [],
                "error": "ContentSnapshotFormalCharacterRegistry expects dictionary entries",
            }
        var validator_path := String(raw_entry.get(VALIDATOR_SCRIPT_PATH_KEY, "")).strip_edges()
        if validator_path.is_empty():
            continue
        var resolved_path := validator_path if validator_path.begins_with("res://") else "res://%s" % validator_path
        var validator_script = load(resolved_path)
        if validator_script == null:
            return {
                "validators": [],
                "error": "ContentSnapshotFormalCharacterRegistry failed to load validator: %s" % validator_path,
            }
        validators.append(validator_script.new())
    return {
        "validators": validators,
        "error": "",
    }
