extends RefCounted
class_name SampleBattleFactoryRuntimeRegistryLoader

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")

var registry_path_override: String = ""
var _manifest = FormalCharacterManifestScript.new()

func load_entries_result() -> Dictionary:
	var load_result: Dictionary = _load_entries()
	var error_message := str(load_result.get("error", "")).strip_edges()
	if not error_message.is_empty():
		return _error_result(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"SampleBattleFactory failed to load formal character runtime registry: %s" % error_message
		)
	return _ok_result(load_result.get("entries", []))

func find_entry_result(character_id: String) -> Dictionary:
	var entries_result := load_entries_result()
	if not bool(entries_result.get("ok", false)):
		return entries_result
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if str(entry.get("character_id", "")).strip_edges() == character_id:
			return _ok_result(entry)
	return _error_result(
		ErrorCodesScript.INVALID_BATTLE_SETUP,
		"SampleBattleFactory unknown character_id: %s" % character_id
	)

func load_entries_for_snapshot_result() -> Dictionary:
	var entries_result := load_entries_result()
	if not bool(entries_result.get("ok", false)):
		return entries_result
	var entries: Array = entries_result.get("data", [])
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
				"SampleBattleFactory formal runtime registry entry must be Dictionary"
			)
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		for raw_rel_path in entry.get("required_content_paths", []):
			var resource_path := _normalize_path(String(raw_rel_path))
			if resource_path.is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
					"SampleBattleFactory registry[%s] has empty required_content_paths entry" % character_id
				)
			if not ResourceLoader.exists(resource_path):
				return _error_result(
					ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
					"SampleBattleFactory missing content snapshot resource: %s" % resource_path
				)
	return _ok_result(entries)

func _load_entries() -> Dictionary:
	_manifest.manifest_path_override = registry_path_override
	var entries_result := _manifest.build_runtime_entries_result()
	if bool(entries_result.get("ok", false)):
		return {
			"entries": entries_result.get("data", []),
			"error": "",
		}
	return {
		"entries": [],
		"error": String(entries_result.get("error_message", "unknown manifest error")),
	}

func _normalize_path(raw_path: String) -> String:
	var trimmed_path := String(raw_path).strip_edges()
	if trimmed_path.is_empty():
		return ""
	return trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
