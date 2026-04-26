extends RefCounted
class_name SampleBattleFactoryBaselineMatchupCatalog

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ResourcePathHelperScript := preload("res://src/shared/resource_path_helper.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const DEFAULT_CATALOG_PATH := "res://config/sample_matchup_catalog.json"
const OVERRIDE_REGISTRY_PATH := "registry_path_override"
const OVERRIDE_BASELINE_MATCHUP_CATALOG_PATH := "baseline_matchup_catalog_path_override"
const OVERRIDE_DEMO_CATALOG_PATH := "demo_catalog_path_override"

var catalog_path_override: String = ""
var override_config: Dictionary = {}
var snapshot_access: SampleBattleFactoryContentPathsHelper = null
var demo_catalog: SampleBattleFactoryDemoCatalog = null

func has_matchup(matchup_id: String) -> bool:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return false
	return catalog_result.get("data", {}).get("matchups", {}).has(matchup_id)

func build_setup_result(setup_access, matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	var spec: Dictionary = catalog_result.get("data", {}).get("matchups", {}).get(matchup_id, {})
	if spec.is_empty():
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory unknown baseline matchup_id: %s" % matchup_id
		)
	var battle_setup = setup_access.build_matchup_setup(
		PackedStringArray(spec.get("p1_units", [])),
		PackedStringArray(spec.get("p2_units", [])),
		side_regular_skill_overrides
	)
	if battle_setup == null:
		return _error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build baseline matchup setup: %s" % matchup_id
		)
	return ResultEnvelopeHelperScript.ok(battle_setup)

func baseline_unit_definition_ids_result() -> Dictionary:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	var matchups: Dictionary = catalog_result.get("data", {}).get("matchups", {})
	var seen: Dictionary = {}
	var unit_definition_ids := PackedStringArray()
	for raw_matchup_id in matchups.keys():
		var matchup_spec: Dictionary = matchups.get(raw_matchup_id, {})
		for side_key in ["p1_units", "p2_units"]:
			for raw_unit_definition_id in matchup_spec.get(side_key, []):
				var unit_definition_id := String(raw_unit_definition_id).strip_edges()
				if unit_definition_id.is_empty() or seen.has(unit_definition_id):
					continue
				seen[unit_definition_id] = true
				unit_definition_ids.append(unit_definition_id)
	return ResultEnvelopeHelperScript.ok(unit_definition_ids)

func load_matchups_result() -> Dictionary:
	return _load_catalog_result()

func configure_registry_path_override(path: String) -> void:
	_set_config_override(OVERRIDE_REGISTRY_PATH, path)

func configure_baseline_matchup_catalog_path_override(path: String) -> void:
	if override_config.is_empty():
		catalog_path_override = path
	else:
		_set_config_override(OVERRIDE_BASELINE_MATCHUP_CATALOG_PATH, path)
	refresh_baseline_unit_definition_ids()

func configure_delivery_registry_path_override(path: String) -> void:
	_set_config_override(OVERRIDE_REGISTRY_PATH, path)

func configure_formal_manifest_path_override(path: String) -> void:
	_set_config_override(OVERRIDE_REGISTRY_PATH, path)

func configure_demo_catalog_path_override(path: String) -> void:
	_set_config_override(OVERRIDE_DEMO_CATALOG_PATH, path)

func refresh_baseline_unit_definition_ids() -> void:
	if snapshot_access == null:
		return
	var baseline_units_result: Dictionary = baseline_unit_definition_ids_result()
	snapshot_access.baseline_unit_definition_ids = baseline_units_result.get("data", PackedStringArray()) if bool(baseline_units_result.get("ok", false)) else PackedStringArray()

func _load_catalog_result() -> Dictionary:
	var resolved_catalog_path := _resolve_catalog_path()
	var file := FileAccess.open(resolved_catalog_path, FileAccess.READ)
	if file == null:
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory missing baseline matchup catalog: %s" % resolved_catalog_path
		)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory expects top-level dictionary baseline matchup catalog: %s" % resolved_catalog_path
		)
	var matchups = parsed.get("matchups", {})
	if not (matchups is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory baseline matchup catalog missing dictionary matchups: %s" % resolved_catalog_path
		)
	for raw_matchup_id in matchups.keys():
		var matchup_id := String(raw_matchup_id).strip_edges()
		var matchup_spec = matchups.get(raw_matchup_id, {})
		if not (matchup_spec is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory baseline matchup catalog[%s] must be dictionary: %s" % [matchup_id, resolved_catalog_path]
			)
		for side_key in ["p1_units", "p2_units"]:
			var units = matchup_spec.get(side_key, [])
			if not (units is Array) or units.is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory baseline matchup catalog[%s].%s must be non-empty array: %s" % [matchup_id, side_key, resolved_catalog_path]
				)
			for raw_unit_id in units:
				if String(raw_unit_id).strip_edges().is_empty():
					return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory baseline matchup catalog[%s].%s contains empty unit_definition_id: %s" % [matchup_id, side_key, resolved_catalog_path]
					)
	return ResultEnvelopeHelperScript.ok(parsed)

func _resolve_catalog_path() -> String:
	return ResourcePathHelperScript.resolve(
		_config_override(OVERRIDE_BASELINE_MATCHUP_CATALOG_PATH, catalog_path_override),
		DEFAULT_CATALOG_PATH
	)

func _set_config_override(key: String, path: String) -> void:
	if override_config.is_empty():
		if key == OVERRIDE_BASELINE_MATCHUP_CATALOG_PATH:
			catalog_path_override = path
		elif key == OVERRIDE_DEMO_CATALOG_PATH and demo_catalog != null:
			demo_catalog.catalog_path_override = path
		elif key == OVERRIDE_REGISTRY_PATH:
			if snapshot_access != null:
				snapshot_access.registry_path_override = path
			return
	override_config[key] = path

func _config_override(key: String, fallback: String = "") -> String:
	if override_config.has(key):
		var value := String(override_config.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return String(fallback).strip_edges()

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)
