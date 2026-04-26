extends RefCounted
class_name SampleBattleFactoryFormalMatchupCatalog

const FormalAccessScript := preload("res://src/composition/sample_battle_factory_formal_access.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const MatchupContractsScript := preload("res://src/composition/sample_battle_factory_matchup_contracts.gd")
const SurfaceBuilderScript := preload("res://src/composition/sample_battle_factory_surface_case_builder.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const OVERRIDE_REGISTRY_PATH := "registry_path_override"
const OVERRIDE_FORMAL_MATCHUP_CATALOG_PATH := "formal_matchup_catalog_path_override"

var catalog_path_override: String = ""
var runtime_registry_path_override: String = ""
var override_config: Dictionary = {}
var _contracts = MatchupContractsScript.new()
var _manifest = FormalCharacterManifestScript.new()
var _runtime_access: SampleBattleFactoryFormalAccess = FormalAccessScript.new()
var _surface_builder: SampleBattleFactorySurfaceCaseBuilder = SurfaceBuilderScript.new()

func has_matchup(matchup_id: String) -> bool:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return false
	return catalog_result.get("data", {}).get("matchups", {}).has(matchup_id)

func build_setup_result(setup_builder, matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	var matchups: Dictionary = catalog_result.get("data", {}).get("matchups", {})
	return _contracts.build_setup_result(setup_builder, matchups, matchup_id, side_regular_skill_overrides)

func load_matchups_result() -> Dictionary:
	return _load_catalog_result()

func formal_pair_surface_cases_result(runtime_entries: Array, delivery_entries: Array) -> Dictionary:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	return _surface_builder.build_surface_cases_result(
		catalog_result.get("data", {}),
		runtime_entries,
		delivery_entries
	)

func formal_pair_smoke_cases_result(runtime_entries: Array, delivery_entries: Array) -> Dictionary:
	return formal_pair_surface_cases_result(runtime_entries, delivery_entries)

func formal_pair_interaction_cases_result() -> Dictionary:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	var raw_bucket = catalog_result.get("data", {}).get("pair_interaction_cases", [])
	var cases: Array = []
	if not (raw_bucket is Array):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory matchup catalog[pair_interaction_cases] must be array"
		)
	for raw_case_spec in raw_bucket:
		if not (raw_case_spec is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases] contains non-dictionary case"
			)
		cases.append(raw_case_spec.duplicate(true))
	return ResultEnvelopeHelperScript.ok(cases)

func _load_catalog_result() -> Dictionary:
	var catalog_result := _load_manifest_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	var parsed: Dictionary = catalog_result.get("data", {})
	var resolved_manifest_path := _resolve_manifest_path()
	var matchups = parsed.get("matchups", {})
	var matchups_validation_result := _contracts.validate_matchups_result(matchups, "formal matchup catalog")
	if not bool(matchups_validation_result.get("ok", false)):
		return matchups_validation_result
	_runtime_access.override_config = override_config
	if override_config.is_empty():
		_runtime_access.registry_path_override = runtime_registry_path_override
	var runtime_entries_result: Dictionary = _runtime_access.load_runtime_entries_result()
	if not bool(runtime_entries_result.get("ok", false)):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory failed to load formal runtime registry for matchup catalog: %s" % String(runtime_entries_result.get("error_message", "unknown error"))
		)
	var runtime_maps_result := _surface_builder.build_runtime_registry_maps_result(runtime_entries_result.get("data", []))
	if not bool(runtime_maps_result.get("ok", false)):
		return runtime_maps_result
	var runtime_maps: Dictionary = runtime_maps_result.get("data", {})
	var known_character_ids: Dictionary = {}
	for raw_character_id in runtime_maps.get("runtime_order", []):
		known_character_ids[String(raw_character_id)] = true
	var unit_to_character: Dictionary = runtime_maps.get("unit_to_character", {})
	var interaction_cases = parsed.get("pair_interaction_cases", [])
	if not (interaction_cases is Array):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory matchup catalog[pair_interaction_cases] must be array: %s" % resolved_manifest_path
		)
	for case_index in range(interaction_cases.size()):
		var case_spec = interaction_cases[case_index]
		if not (case_spec is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases][%d] must be dictionary: %s" % [case_index, resolved_manifest_path]
			)
		for required_key in ["test_name", "matchup_id", "scenario_key"]:
			if String(case_spec.get(required_key, "")).strip_edges().is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory matchup catalog[pair_interaction_cases][%d] missing %s: %s" % [case_index, required_key, resolved_manifest_path]
				)
		var matchup_id := String(case_spec.get("matchup_id", "")).strip_edges()
		if not matchups.has(matchup_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases][%d] unknown matchup_id: %s (%s)" % [case_index, matchup_id, resolved_manifest_path]
			)
		var matchup_spec: Dictionary = matchups.get(matchup_id, {})
		if bool(matchup_spec.get("test_only", false)):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases][%d] must not reference test_only matchup_id: %s (%s)" % [case_index, matchup_id, resolved_manifest_path]
			)
		var character_ids = case_spec.get("character_ids", [])
		if not (character_ids is Array) or character_ids.size() != 2:
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases][%d].character_ids must contain exactly two entries: %s" % [case_index, resolved_manifest_path]
			)
		var left_character_id := String(character_ids[0]).strip_edges()
		var right_character_id := String(character_ids[1]).strip_edges()
		if left_character_id.is_empty() or right_character_id.is_empty() or left_character_id == right_character_id:
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases][%d].character_ids must contain two distinct non-empty entries: %s" % [case_index, resolved_manifest_path]
			)
		if not known_character_ids.has(left_character_id) or not known_character_ids.has(right_character_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases][%d].character_ids must reference known formal characters: %s" % [case_index, resolved_manifest_path]
			)
		var matchup_direction := _matchup_formal_direction(matchup_spec, unit_to_character)
		if matchup_direction[0] != left_character_id or matchup_direction[1] != right_character_id:
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases][%d].character_ids must match matchup opener direction: %s (%s)" % [case_index, matchup_id, resolved_manifest_path]
			)
	return ResultEnvelopeHelperScript.ok(parsed)

func _matchup_formal_direction(matchup_spec: Dictionary, unit_to_character: Dictionary) -> Array:
	var matchup_direction := ["", ""]
	var p1_units = matchup_spec.get("p1_units", [])
	var p2_units = matchup_spec.get("p2_units", [])
	if p1_units is Array and not p1_units.is_empty():
		matchup_direction[0] = String(unit_to_character.get(String(p1_units[0]).strip_edges(), "")).strip_edges()
	if p2_units is Array and not p2_units.is_empty():
		matchup_direction[1] = String(unit_to_character.get(String(p2_units[0]).strip_edges(), "")).strip_edges()
	return matchup_direction

func _load_manifest_catalog_result() -> Dictionary:
	_manifest.manifest_path_override = _resolve_manifest_path()
	var catalog_result := _manifest.build_catalog_result()
	if bool(catalog_result.get("ok", false)):
		return catalog_result
	return _error_result(
		ErrorCodesScript.INVALID_BATTLE_SETUP,
		String(catalog_result.get("error_message", "unknown manifest error"))
	)

func _resolve_manifest_path() -> String:
	var trimmed_catalog_path := _config_override(OVERRIDE_FORMAL_MATCHUP_CATALOG_PATH, catalog_path_override)
	if not trimmed_catalog_path.is_empty():
		return trimmed_catalog_path
	return _config_override(OVERRIDE_REGISTRY_PATH, runtime_registry_path_override)

func _config_override(key: String, fallback: String = "") -> String:
	if override_config.has(key):
		var value := String(override_config.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return String(fallback).strip_edges()

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)
