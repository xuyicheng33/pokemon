extends RefCounted
class_name SampleBattleFactoryMatchupCatalog

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const DEFAULT_CATALOG_PATH := "res://config/formal_matchup_catalog.json"

var catalog_path_override: String = ""

func has_matchup(matchup_id: String) -> bool:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return false
	return catalog_result.get("data", {}).get("matchups", {}).has(matchup_id)

func build_setup(setup_builder, matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Variant:
	var result := build_setup_result(setup_builder, matchup_id, side_regular_skill_overrides)
	if not bool(result.get("ok", false)):
		return null
	return result.get("data", null)

func build_setup_result(setup_builder, matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	var spec: Dictionary = catalog_result.get("data", {}).get("matchups", {}).get(matchup_id, {})
	if spec.is_empty():
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory unknown matchup_id: %s" % matchup_id
		)
	var battle_setup = setup_builder.build_matchup_setup(
		PackedStringArray(spec.get("p1_units", [])),
		PackedStringArray(spec.get("p2_units", [])),
		side_regular_skill_overrides
	)
	if battle_setup == null:
		return _error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build matchup setup: %s" % matchup_id
		)
	return _ok_result(battle_setup)

func formal_pair_surface_cases() -> Array:
	return _copy_case_bucket("pair_surface_cases")

func formal_pair_smoke_cases() -> Array:
	return formal_pair_surface_cases()

func formal_pair_interaction_cases() -> Array:
	return _copy_case_bucket("pair_interaction_cases")

func _copy_case_bucket(bucket_name: String) -> Array:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return []
	var raw_bucket = catalog_result.get("data", {}).get(bucket_name, [])
	var cases: Array = []
	if not (raw_bucket is Array):
		return cases
	for raw_case_spec in raw_bucket:
		if not (raw_case_spec is Dictionary):
			continue
		cases.append(raw_case_spec.duplicate(true))
	return cases

func _load_catalog_result() -> Dictionary:
	var resolved_catalog_path := _resolve_catalog_path()
	var file := FileAccess.open(resolved_catalog_path, FileAccess.READ)
	if file == null:
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory missing matchup catalog: %s" % resolved_catalog_path
		)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory expects top-level dictionary matchup catalog: %s" % resolved_catalog_path
		)
	var matchups = parsed.get("matchups", {})
	if not (matchups is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory matchup catalog missing dictionary matchups: %s" % resolved_catalog_path
		)
	for matchup_id in matchups.keys():
		var matchup_spec = matchups.get(matchup_id, {})
		if not (matchup_spec is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[%s] must be dictionary: %s" % [String(matchup_id), resolved_catalog_path]
			)
		for side_key in ["p1_units", "p2_units"]:
			var units = matchup_spec.get(side_key, [])
			if not (units is Array) or units.is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory matchup catalog[%s].%s must be non-empty array: %s" % [String(matchup_id), side_key, resolved_catalog_path]
				)
	for bucket_name in ["pair_surface_cases", "pair_interaction_cases"]:
		var bucket = parsed.get(bucket_name, [])
		if not (bucket is Array):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[%s] must be array: %s" % [bucket_name, resolved_catalog_path]
			)
		for case_index in range(bucket.size()):
			var case_spec = bucket[case_index]
			if not (case_spec is Dictionary):
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory matchup catalog[%s][%d] must be dictionary: %s" % [bucket_name, case_index, resolved_catalog_path]
				)
			for required_key in ["test_name", "matchup_id"]:
				if String(case_spec.get(required_key, "")).strip_edges().is_empty():
					return _error_result(
						ErrorCodesScript.INVALID_BATTLE_SETUP,
						"SampleBattleFactory matchup catalog[%s][%d] missing %s: %s" % [bucket_name, case_index, required_key, resolved_catalog_path]
					)
			if bucket_name == "pair_surface_cases":
				for required_key in ["p1_character_id", "p2_character_id", "p1_unit_definition_id", "p2_unit_definition_id", "p1_skill_id", "p2_skill_id"]:
					if String(case_spec.get(required_key, "")).strip_edges().is_empty():
						return _error_result(
							ErrorCodesScript.INVALID_BATTLE_SETUP,
							"SampleBattleFactory matchup catalog[%s][%d] missing %s: %s" % [bucket_name, case_index, required_key, resolved_catalog_path]
						)
			else:
				if String(case_spec.get("scenario_id", "")).strip_edges().is_empty():
					return _error_result(
						ErrorCodesScript.INVALID_BATTLE_SETUP,
						"SampleBattleFactory matchup catalog[%s][%d] missing scenario_id: %s" % [bucket_name, case_index, resolved_catalog_path]
					)
				var character_ids = case_spec.get("character_ids", [])
				if not (character_ids is Array) or character_ids.size() != 2:
					return _error_result(
						ErrorCodesScript.INVALID_BATTLE_SETUP,
						"SampleBattleFactory matchup catalog[%s][%d].character_ids must contain exactly two entries: %s" % [bucket_name, case_index, resolved_catalog_path]
					)
	return _ok_result(parsed)

func _resolve_catalog_path() -> String:
	var trimmed_path := String(catalog_path_override).strip_edges()
	if trimmed_path.is_empty():
		return DEFAULT_CATALOG_PATH
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
