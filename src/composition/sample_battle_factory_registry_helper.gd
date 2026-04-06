extends RefCounted
class_name SampleBattleFactoryRegistryHelper

const FormalCharacterRegistryScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var registry_path_override: String = ""

func load_entries_result() -> Dictionary:
	var load_result: Dictionary = _load_entries()
	var error_message := str(load_result.get("error", "")).strip_edges()
	if not error_message.is_empty():
		return error_result(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"SampleBattleFactory failed to load formal character runtime registry: %s" % error_message
		)
	return ok_result(load_result.get("entries", []))

func find_entry_result(character_id: String) -> Dictionary:
	var entries_result := load_entries_result()
	if not bool(entries_result.get("ok", false)):
		return entries_result
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if str(entry.get("character_id", "")).strip_edges() == character_id:
			return ok_result(entry)
	return error_result(
		ErrorCodesScript.INVALID_BATTLE_SETUP,
		"SampleBattleFactory unknown character_id: %s" % character_id
	)

func _load_entries() -> Dictionary:
	var resolved_override_path := _normalize_path(registry_path_override)
	if resolved_override_path.is_empty():
		return FormalCharacterRegistryScript.load_entries()
	return FormalCharacterRegistryScript.load_entries_from_path(resolved_override_path)

func _normalize_path(raw_path: String) -> String:
	var trimmed_path := String(raw_path).strip_edges()
	if trimmed_path.is_empty():
		return ""
	return trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path

func ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
