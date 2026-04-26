extends RefCounted
class_name SampleBattleFactoryFormalAccess

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const ResourcePathHelperScript := preload("res://src/shared/resource_path_helper.gd")
const OVERRIDE_REGISTRY_PATH := "registry_path_override"

var registry_path_override: String = ""
var override_config: Dictionary = {}
var formal_matchup_catalog: SampleBattleFactoryFormalMatchupCatalog = null
var setup_access: SampleBattleFactorySetupAccess = null
var _manifest = FormalCharacterManifestScript.new()

func formal_ids_result(entry_key: String) -> Dictionary:
	var ids := PackedStringArray()
	var entries_result: Dictionary = load_runtime_entries_result()
	if not bool(entries_result.get("ok", false)):
		return entries_result
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		var entry_id := String(entry.get(entry_key, "")).strip_edges()
		if not entry_id.is_empty():
			ids.append(entry_id)
	return ResultEnvelopeHelperScript.ok(ids)

func build_formal_character_setup_result(character_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var entry_result: Dictionary = find_runtime_entry_result(character_id)
	if not bool(entry_result.get("ok", false)):
		return entry_result
	var entry: Dictionary = entry_result.get("data", {})
	var matchup_id := String(entry.get("formal_setup_matchup_id", "")).strip_edges()
	if matchup_id.is_empty():
		return _error_result(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"SampleBattleFactory registry[%s] missing formal_setup_matchup_id" % character_id
		)
	if setup_access != null \
	and setup_access.baseline_matchup_catalog != null \
	and setup_access.baseline_matchup_catalog.has_matchup(matchup_id):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory registry[%s] formal_setup_matchup_id collides with baseline matchup_id: %s" % [
				character_id,
				matchup_id,
			]
		)
	var setup_result: Dictionary = formal_matchup_catalog.build_setup_result(
		setup_access,
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
	return ResultEnvelopeHelperScript.ok(setup_result.get("data", null))

func formal_pair_smoke_cases_result() -> Dictionary:
	var registries_result := _load_runtime_and_delivery_entries_result()
	if not bool(registries_result.get("ok", false)):
		return registries_result
	var registries: Dictionary = registries_result.get("data", {})
	return formal_matchup_catalog.formal_pair_smoke_cases_result(
		registries.get("runtime_entries", []),
		registries.get("delivery_entries", [])
	)

func formal_pair_surface_cases_result() -> Dictionary:
	var registries_result := _load_runtime_and_delivery_entries_result()
	if not bool(registries_result.get("ok", false)):
		return registries_result
	var registries: Dictionary = registries_result.get("data", {})
	return formal_matchup_catalog.formal_pair_surface_cases_result(
		registries.get("runtime_entries", []),
		registries.get("delivery_entries", [])
	)

func formal_pair_interaction_cases_result() -> Dictionary:
	return formal_matchup_catalog.formal_pair_interaction_cases_result()

func load_runtime_entries_result() -> Dictionary:
	_manifest.manifest_path_override = _registry_path_override()
	var entries_result := _manifest.build_runtime_entries_result()
	if bool(entries_result.get("ok", false)):
		return ResultEnvelopeHelperScript.ok(entries_result.get("data", []))
	return _error_result(
		ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
		"SampleBattleFactory failed to load formal character runtime registry: %s" % String(entries_result.get("error_message", "unknown manifest error"))
	)

func load_delivery_entries_result() -> Dictionary:
	_manifest.manifest_path_override = _registry_path_override()
	var entries_result := _manifest.build_delivery_entries_result()
	if bool(entries_result.get("ok", false)):
		return ResultEnvelopeHelperScript.ok(entries_result.get("data", []))
	return _error_result(
		ErrorCodesScript.INVALID_BATTLE_SETUP,
		String(entries_result.get("error_message", "unknown manifest error"))
	)

func find_runtime_entry_result(character_id: String) -> Dictionary:
	var entries_result := load_runtime_entries_result()
	if not bool(entries_result.get("ok", false)):
		return entries_result
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if str(entry.get("character_id", "")).strip_edges() == character_id:
			return ResultEnvelopeHelperScript.ok(entry)
	return _error_result(
		ErrorCodesScript.INVALID_BATTLE_SETUP,
		"SampleBattleFactory unknown character_id: %s" % character_id
	)

func load_runtime_entries_for_snapshot_result() -> Dictionary:
	var entries_result := load_runtime_entries_result()
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
	return ResultEnvelopeHelperScript.ok(entries)

func _load_runtime_and_delivery_entries_result() -> Dictionary:
	var runtime_entries_result: Dictionary = load_runtime_entries_result()
	if not bool(runtime_entries_result.get("ok", false)):
		return runtime_entries_result
	var delivery_entries_result: Dictionary = load_delivery_entries_result()
	if not bool(delivery_entries_result.get("ok", false)):
		return delivery_entries_result
	return ResultEnvelopeHelperScript.ok({
		"runtime_entries": runtime_entries_result.get("data", []),
		"delivery_entries": delivery_entries_result.get("data", []),
	})

func _normalize_path(raw_path: String) -> String:
	return ResourcePathHelperScript.normalize(raw_path)

func _registry_path_override() -> String:
	if override_config.has(OVERRIDE_REGISTRY_PATH):
		var path := String(override_config.get(OVERRIDE_REGISTRY_PATH, "")).strip_edges()
		if not path.is_empty():
			return path
	return String(registry_path_override).strip_edges()

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)
