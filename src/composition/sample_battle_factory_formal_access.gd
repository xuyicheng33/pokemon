extends RefCounted
class_name SampleBattleFactoryFormalAccess

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var delivery_registry_loader
var formal_matchup_catalog
var runtime_registry_loader
var setup_builder

func formal_ids_result(entry_key: String) -> Dictionary:
	var ids := PackedStringArray()
	var entries_result: Dictionary = runtime_registry_loader.load_entries_result()
	if not bool(entries_result.get("ok", false)):
		return entries_result
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		var entry_id := String(entry.get(entry_key, "")).strip_edges()
		if not entry_id.is_empty():
			ids.append(entry_id)
	return _ok_result(ids)

func build_formal_character_setup_result(character_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var entry_result: Dictionary = runtime_registry_loader.find_entry_result(character_id)
	if not bool(entry_result.get("ok", false)):
		return entry_result
	var entry: Dictionary = entry_result.get("data", {})
	var matchup_id := String(entry.get("formal_setup_matchup_id", "")).strip_edges()
	if matchup_id.is_empty():
		return _error_result(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"SampleBattleFactory registry[%s] missing formal_setup_matchup_id" % character_id
		)
	var setup_result: Dictionary = formal_matchup_catalog.build_setup_result(
		setup_builder,
		matchup_id,
		side_regular_skill_overrides
	)
	if not bool(setup_result.get("ok", false)):
		return _error_result(
			str(setup_result.get("error_code", ErrorCodesScript.INVALID_BATTLE_SETUP)),
			"SampleBattleFactory registry[%s] failed to build formal setup matchup %s: %s" % [
				character_id,
				matchup_id,
				String(setup_result.get("error_message", "unknown error")),
			]
		)
	return _ok_result(setup_result.get("data", null))

func formal_pair_smoke_cases_result() -> Dictionary:
	var registries_result := _load_runtime_and_delivery_entries_result()
	if not bool(registries_result.get("ok", false)):
		return registries_result
	return formal_matchup_catalog.formal_pair_smoke_cases_result(
		registries_result.get("runtime_entries", []),
		registries_result.get("delivery_entries", [])
	)

func formal_pair_surface_cases_result() -> Dictionary:
	var registries_result := _load_runtime_and_delivery_entries_result()
	if not bool(registries_result.get("ok", false)):
		return registries_result
	return formal_matchup_catalog.formal_pair_surface_cases_result(
		registries_result.get("runtime_entries", []),
		registries_result.get("delivery_entries", [])
	)

func formal_pair_interaction_cases_result() -> Dictionary:
	return formal_matchup_catalog.formal_pair_interaction_cases_result()

func _load_runtime_and_delivery_entries_result() -> Dictionary:
	var runtime_entries_result: Dictionary = runtime_registry_loader.load_entries_result()
	if not bool(runtime_entries_result.get("ok", false)):
		return runtime_entries_result
	var delivery_entries_result: Dictionary = delivery_registry_loader.load_entries_result()
	if not bool(delivery_entries_result.get("ok", false)):
		return delivery_entries_result
	return {
		"ok": true,
		"runtime_entries": runtime_entries_result.get("data", []),
		"delivery_entries": delivery_entries_result.get("data", []),
		"error_code": null,
		"error_message": null,
	}

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
