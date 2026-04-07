extends RefCounted
class_name SampleBattleFactoryDeliveryRegistryLoader

const FormalRegistryContractsScript := preload("res://src/shared/formal_registry_contracts.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const REGISTRY_PATH := "res://config/formal_character_delivery_registry.json"

var registry_path_override: String = ""
var _registry_contracts = FormalRegistryContractsScript.new()

func load_entries_result() -> Dictionary:
	var contracts_result := _registry_contracts.load_contracts_result()
	if not bool(contracts_result.get("ok", false)):
		return contracts_result
	var resolved_registry_path := _resolve_registry_path(registry_path_override)
	var file := FileAccess.open(resolved_registry_path, FileAccess.READ)
	if file == null:
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory missing formal character delivery registry: %s" % resolved_registry_path
		)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory expects top-level array delivery registry: %s" % resolved_registry_path
		)
	var entries: Array = []
	var seen_character_ids: Dictionary = {}
	for raw_entry in parsed:
		if not (raw_entry is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory expects dictionary delivery registry entries"
			)
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry entry missing character_id"
			)
		if seen_character_ids.has(character_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry duplicated character_id: %s" % character_id
			)
		seen_character_ids[character_id] = true
		var field_result := _registry_contracts.validate_required_fields_result(
			FormalRegistryContractsScript.DELIVERY_REGISTRY_BUCKET,
			entry,
			"SampleBattleFactory delivery registry[%s]" % character_id
		)
		if not bool(field_result.get("ok", false)):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				String(field_result.get("error_message", "unknown field validation error"))
			)
		entries.append(entry.duplicate(true))
	return _ok_result(entries)

func _resolve_registry_path(registry_path: String) -> String:
	var normalized_path := String(registry_path).strip_edges()
	if normalized_path.is_empty():
		return REGISTRY_PATH
	return normalized_path if normalized_path.begins_with("res://") or normalized_path.begins_with("user://") else "res://%s" % normalized_path

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
