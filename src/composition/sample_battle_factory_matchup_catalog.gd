extends RefCounted
class_name SampleBattleFactoryFormalMatchupCatalog

const LoaderScript := preload("res://src/composition/sample_battle_factory_matchup_catalog_loader.gd")
const MatchupContractsScript := preload("res://src/composition/sample_battle_factory_matchup_contracts.gd")
const SurfaceBuilderScript := preload("res://src/composition/sample_battle_factory_surface_case_builder.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var catalog_path_override: String = ""
var runtime_registry_path_override: String = ""
var _contracts = MatchupContractsScript.new()

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

func formal_pair_surface_cases_result(runtime_entries: Array, delivery_entries: Array) -> Dictionary:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	return SurfaceBuilderScript.new().build_surface_cases_result(
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
	return _ok_result(cases)

func _load_catalog_result() -> Dictionary:
	var loader = LoaderScript.new()
	loader.catalog_path_override = catalog_path_override
	loader.runtime_registry_path_override = runtime_registry_path_override
	return loader.load_catalog_result()

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
