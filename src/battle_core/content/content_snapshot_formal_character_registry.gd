extends RefCounted
class_name ContentSnapshotFormalCharacterRegistry

const FORMAL_CHARACTER_DESCRIPTORS := [
	{
		"character_id": "gojo_satoru",
		"validator_script": preload("res://src/battle_core/content/content_snapshot_formal_gojo_validator.gd"),
	},
	{
		"character_id": "sukuna",
		"validator_script": preload("res://src/battle_core/content/content_snapshot_formal_sukuna_validator.gd"),
	},
	{
		"character_id": "kashimo_hajime",
		"validator_script": preload("res://src/battle_core/content/content_snapshot_formal_kashimo_validator.gd"),
	},
]

static func build_validator_instances() -> Dictionary:
	var validators: Array = []
	var seen_character_ids: Dictionary = {}
	for raw_descriptor in FORMAL_CHARACTER_DESCRIPTORS:
		if not (raw_descriptor is Dictionary):
			return {
				"validators": [],
				"error": "ContentSnapshotFormalCharacterRegistry expects dictionary descriptors",
			}
		var character_id := String(raw_descriptor.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			return {
				"validators": [],
				"error": "ContentSnapshotFormalCharacterRegistry descriptor missing character_id",
			}
		if seen_character_ids.has(character_id):
			return {
				"validators": [],
				"error": "ContentSnapshotFormalCharacterRegistry duplicated character_id: %s" % character_id,
			}
		seen_character_ids[character_id] = true
		var validator_script = raw_descriptor.get("validator_script", null)
		if validator_script == null:
			return {
				"validators": [],
				"error": "ContentSnapshotFormalCharacterRegistry[%s] missing validator_script" % character_id,
			}
		if not (validator_script is Script) or not validator_script.can_instantiate():
			return {
				"validators": [],
				"error": "ContentSnapshotFormalCharacterRegistry[%s] validator is not instantiable" % character_id,
			}
		var validator_instance = validator_script.new()
		if validator_instance == null:
			return {
				"validators": [],
				"error": "ContentSnapshotFormalCharacterRegistry[%s] failed to instantiate validator" % character_id,
			}
		validators.append(validator_instance)
	return {
		"validators": validators,
		"error": "",
	}
