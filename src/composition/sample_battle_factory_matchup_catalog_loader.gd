extends RefCounted
class_name SampleBattleFactoryFormalMatchupCatalogLoader

const FormalContractsScript := preload("res://src/composition/sample_battle_factory_formal_contracts.gd")
const MatchupContractsScript := preload("res://src/composition/sample_battle_factory_matchup_contracts.gd")
const RuntimeRegistryLoaderScript := preload("res://src/composition/sample_battle_factory_runtime_registry_loader.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var catalog_path_override: String = ""
var runtime_registry_path_override: String = ""

var _formal_contracts = FormalContractsScript.new()
var _matchup_contracts = MatchupContractsScript.new()
var _manifest = FormalCharacterManifestScript.new()

func load_catalog_result() -> Dictionary:
	var catalog_result := _load_manifest_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	var parsed: Dictionary = catalog_result.get("data", {})
	var resolved_manifest_path := _resolve_manifest_path()
	var matchups = parsed.get("matchups", {})
	var matchups_validation_result := _matchup_contracts.validate_matchups_result(matchups, "formal matchup catalog")
	if not bool(matchups_validation_result.get("ok", false)):
		return matchups_validation_result
	var runtime_entries_result := _load_runtime_registry_entries_result()
	if not bool(runtime_entries_result.get("ok", false)):
		return runtime_entries_result
	var runtime_maps_result := _formal_contracts.build_runtime_registry_maps_result(runtime_entries_result.get("data", []))
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
		for required_key in ["test_name", "matchup_id", "scenario_id"]:
			if String(case_spec.get(required_key, "")).strip_edges().is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory matchup catalog[pair_interaction_cases][%d] missing %s: %s" % [case_index, required_key, resolved_manifest_path]
				)
		var matchup_id := String(case_spec.get("matchup_id", "")).strip_edges()
		if not matchups.has(matchup_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases][%d] unknown matchup_id: %s (%s)" % [
					case_index,
					matchup_id,
					resolved_manifest_path,
				]
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
		var matchup_spec: Dictionary = matchups.get(matchup_id, {})
		var matchup_pair := _matchup_formal_pair(matchup_spec, unit_to_character)
		var expected_pair := [left_character_id, right_character_id]
		expected_pair.sort()
		if matchup_pair != expected_pair:
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[pair_interaction_cases][%d].character_ids must match matchup opener formal pair: %s" % [case_index, resolved_manifest_path]
			)
		var battle_seed_result := _formal_contracts.parse_positive_int_result(
			case_spec.get("battle_seed", null),
			"SampleBattleFactory matchup catalog[pair_interaction_cases][%d].battle_seed must be positive integer: %s" % [
				case_index,
				resolved_manifest_path,
			]
		)
		if not bool(battle_seed_result.get("ok", false)):
			return battle_seed_result
		case_spec["battle_seed"] = int(battle_seed_result.get("data", 0))
	return _ok_result(parsed)

func _matchup_formal_pair(matchup_spec: Dictionary, unit_to_character: Dictionary) -> Array:
	var matchup_pair := ["", ""]
	var p1_units = matchup_spec.get("p1_units", [])
	var p2_units = matchup_spec.get("p2_units", [])
	if p1_units is Array and not p1_units.is_empty():
		matchup_pair[0] = String(unit_to_character.get(String(p1_units[0]).strip_edges(), "")).strip_edges()
	if p2_units is Array and not p2_units.is_empty():
		matchup_pair[1] = String(unit_to_character.get(String(p2_units[0]).strip_edges(), "")).strip_edges()
	matchup_pair.sort()
	return matchup_pair

func _load_runtime_registry_entries_result() -> Dictionary:
	var loader = RuntimeRegistryLoaderScript.new()
	loader.registry_path_override = runtime_registry_path_override
	var entries_result: Dictionary = loader.load_entries_result()
	if not bool(entries_result.get("ok", false)):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory failed to load formal runtime registry for matchup catalog: %s" % String(entries_result.get("error_message", "unknown error"))
		)
	return _ok_result(entries_result.get("data", []))

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
	var trimmed_catalog_path := String(catalog_path_override).strip_edges()
	if not trimmed_catalog_path.is_empty():
		return trimmed_catalog_path
	return String(runtime_registry_path_override).strip_edges()

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
