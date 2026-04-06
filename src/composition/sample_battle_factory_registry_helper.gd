extends RefCounted
class_name SampleBattleFactoryRegistryHelper

const FormalCharacterRegistryScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func load_entries_result() -> Dictionary:
	var load_result: Dictionary = FormalCharacterRegistryScript.load_entries()
	var error_message := str(load_result.get("error", "")).strip_edges()
	if not error_message.is_empty():
		return error_result(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"SampleBattleFactory failed to load formal character registry: %s" % error_message
		)
	return ok_result(load_result.get("entries", []))

func find_entry_result(formal_character_definition_id: String) -> Dictionary:
	var entries_result := load_entries_result()
	if not bool(entries_result.get("ok", false)):
		return entries_result
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if str(entry.get("character_id", "")).strip_edges() == formal_character_definition_id:
			return ok_result(entry)
	return error_result(
		ErrorCodesScript.INVALID_BATTLE_SETUP,
		"SampleBattleFactory unknown formal_character_definition_id: %s" % formal_character_definition_id
	)

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
