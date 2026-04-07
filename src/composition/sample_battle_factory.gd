extends RefCounted
class_name SampleBattleFactory

const BaselineMatchupCatalogScript := preload("res://src/composition/sample_battle_factory_baseline_matchup_catalog.gd")
const ContentPathsHelperScript := preload("res://src/composition/sample_battle_factory_content_paths_helper.gd")
const DeliveryRegistryLoaderScript := preload("res://src/composition/sample_battle_factory_delivery_registry_loader.gd")
const DemoCatalogScript := preload("res://src/composition/sample_battle_factory_demo_catalog.gd")
const MatchupCatalogScript := preload("res://src/composition/sample_battle_factory_matchup_catalog.gd")
const ReplayBuilderScript := preload("res://src/composition/sample_battle_factory_replay_builder.gd")
const RuntimeRegistryLoaderScript := preload("res://src/composition/sample_battle_factory_runtime_registry_loader.gd")
const SetupBuilderScript := preload("res://src/composition/sample_battle_factory_setup_builder.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var _baseline_matchup_catalog = BaselineMatchupCatalogScript.new()
var _content_paths_helper = ContentPathsHelperScript.new()
var _delivery_registry_loader = DeliveryRegistryLoaderScript.new()
var _demo_catalog = DemoCatalogScript.new()
var _formal_matchup_catalog = MatchupCatalogScript.new()
var _replay_builder = ReplayBuilderScript.new()
var _runtime_registry_loader = RuntimeRegistryLoaderScript.new()
var _setup_builder = SetupBuilderScript.new()
var last_error_code: Variant = null
var last_error_message: String = ""

func _init() -> void:
	_refresh_baseline_unit_definition_ids()

func configure_registry_path_override(path: String) -> void:
	_runtime_registry_loader.registry_path_override = path
	_content_paths_helper.registry_path_override = path
	_formal_matchup_catalog.runtime_registry_path_override = path

func configure_baseline_matchup_catalog_path_override(path: String) -> void:
	_baseline_matchup_catalog.catalog_path_override = path
	_refresh_baseline_unit_definition_ids()

func configure_matchup_catalog_path_override(path: String) -> void:
	_formal_matchup_catalog.catalog_path_override = path

func configure_delivery_registry_path_override(path: String) -> void:
	_delivery_registry_loader.registry_path_override = path

func configure_demo_catalog_path_override(path: String) -> void:
	_demo_catalog.catalog_path_override = path

func default_demo_profile_id() -> String:
	return _demo_catalog.default_profile_id()

func error_state() -> Dictionary:
	return {
		"code": last_error_code,
		"message": last_error_message,
	}

func build_side_spec(
	unit_definition_ids: PackedStringArray,
	starting_index: int = 0,
	regular_skill_loadout_overrides: Dictionary = {}
) -> Dictionary:
	return _setup_builder.build_side_spec(unit_definition_ids, starting_index, regular_skill_loadout_overrides)

func build_setup_from_side_specs_result(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Dictionary:
	var battle_setup = _setup_builder.build_setup_from_side_specs(p1_side_spec, p2_side_spec)
	if battle_setup == null:
		return _record_result(_error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build setup from side specs"
		))
	return _record_result(_ok_result(battle_setup))

func content_snapshot_paths_result() -> Dictionary:
	return _record_result(_content_paths_helper.build_snapshot_paths(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS))

func content_snapshot_paths_for_setup_result(battle_setup) -> Dictionary:
	return _record_result(_content_paths_helper.build_snapshot_paths_for_setup(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS, battle_setup))

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	return _record_result(_content_paths_helper.collect_tres_paths_result(dir_path))

func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary:
	return _record_result(_content_paths_helper.collect_tres_paths_recursive_result(dir_path))

func build_setup_by_matchup_id_result(matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	if _baseline_matchup_catalog.has_matchup(matchup_id):
		return _record_result(_baseline_matchup_catalog.build_setup_result(_setup_builder, matchup_id, side_regular_skill_overrides))
	return _record_result(_formal_matchup_catalog.build_setup_result(_setup_builder, matchup_id, side_regular_skill_overrides))

func build_matchup_setup_result(
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary = {},
	p1_starting_index: int = 0,
	p2_starting_index: int = 0
) -> Dictionary:
	var battle_setup = _setup_builder.build_matchup_setup(
		p1_unit_definition_ids,
		p2_unit_definition_ids,
		side_regular_skill_overrides,
		p1_starting_index,
		p2_starting_index
	)
	if battle_setup == null:
		return _record_result(_error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build matchup setup"
		))
	return _record_result(_ok_result(battle_setup))

func formal_character_ids_result() -> Dictionary:
	return _formal_ids_result("character_id")

func formal_unit_definition_ids_result() -> Dictionary:
	return _formal_ids_result("unit_definition_id")

func _formal_ids_result(entry_key: String) -> Dictionary:
	var ids := PackedStringArray()
	var entries_result := _runtime_registry_loader.load_entries_result()
	if not bool(entries_result.get("ok", false)):
		return _record_result(entries_result)
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		var entry_id := str(entry.get(entry_key, "")).strip_edges()
		if entry_id.is_empty():
			continue
		ids.append(entry_id)
	return _record_result(_ok_result(ids))

func build_formal_character_setup_result(character_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var entry_result := _runtime_registry_loader.find_entry_result(character_id)
	if not bool(entry_result.get("ok", false)):
		return _record_result(entry_result)
	var entry: Dictionary = entry_result.get("data", {})
	var matchup_id := str(entry.get("formal_setup_matchup_id", "")).strip_edges()
	if matchup_id.is_empty():
		return _record_result(_error_result(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"SampleBattleFactory registry[%s] missing formal_setup_matchup_id" % character_id
		))
	var setup_result := _formal_matchup_catalog.build_setup_result(_setup_builder, matchup_id, side_regular_skill_overrides)
	if not bool(setup_result.get("ok", false)):
		return _record_result(_error_result(
			str(setup_result.get("error_code", ErrorCodesScript.INVALID_BATTLE_SETUP)),
			"SampleBattleFactory registry[%s] failed to build formal setup matchup %s: %s" % [
				character_id,
				matchup_id,
				String(setup_result.get("error_message", "unknown error")),
			]
		))
	return _record_result(_ok_result(setup_result.get("data", null)))

func formal_pair_smoke_cases_result() -> Dictionary:
	var runtime_entries_result := _runtime_registry_loader.load_entries_result()
	if not bool(runtime_entries_result.get("ok", false)):
		return _record_result(runtime_entries_result)
	var delivery_entries_result := _delivery_registry_loader.load_entries_result()
	if not bool(delivery_entries_result.get("ok", false)):
		return _record_result(delivery_entries_result)
	return _record_result(_formal_matchup_catalog.formal_pair_smoke_cases_result(
		runtime_entries_result.get("data", []),
		delivery_entries_result.get("data", [])
	))

func formal_pair_surface_cases_result() -> Dictionary:
	var runtime_entries_result := _runtime_registry_loader.load_entries_result()
	if not bool(runtime_entries_result.get("ok", false)):
		return _record_result(runtime_entries_result)
	var delivery_entries_result := _delivery_registry_loader.load_entries_result()
	if not bool(delivery_entries_result.get("ok", false)):
		return _record_result(delivery_entries_result)
	return _record_result(_formal_matchup_catalog.formal_pair_surface_cases_result(
		runtime_entries_result.get("data", []),
		delivery_entries_result.get("data", [])
	))

func formal_pair_interaction_cases_result() -> Dictionary:
	return _record_result(_formal_matchup_catalog.formal_pair_interaction_cases_result())

func build_sample_setup_result(side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return _record_result(_baseline_matchup_catalog.build_setup_result(_setup_builder, "sample_default", side_regular_skill_overrides))

func build_demo_replay_input_result(command_port, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_demo_replay_input_for_profile_result(command_port, default_demo_profile_id(), side_regular_skill_overrides)

func build_demo_replay_input_for_profile_result(command_port, demo_profile_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var profile_result: Dictionary = _demo_catalog.profile_result(demo_profile_id)
	if not bool(profile_result.get("ok", false)):
		return _record_result(profile_result)
	var profile: Dictionary = profile_result.get("data", {})
	var matchup_id := String(profile.get("matchup_id", "")).strip_edges()
	var battle_setup_result := build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides)
	if not bool(battle_setup_result.get("ok", false)):
		return _record_result(_error_result(
			str(battle_setup_result.get("error_code", ErrorCodesScript.INVALID_BATTLE_SETUP)),
			"SampleBattleFactory demo replay profile[%s] failed to build matchup %s: %s" % [
				demo_profile_id,
				matchup_id,
				String(battle_setup_result.get("error_message", "unknown error")),
			]
		))
	var battle_setup = battle_setup_result.get("data", null)
	var snapshot_paths_result := _content_paths_helper.build_base_snapshot_paths(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS) if _baseline_matchup_catalog.has_matchup(matchup_id) else content_snapshot_paths_for_setup_result(battle_setup)
	if not bool(snapshot_paths_result.get("ok", false)):
		return _record_result(snapshot_paths_result)
	return _record_result(_replay_builder.build_replay_input_result(
		command_port,
		snapshot_paths_result,
		battle_setup,
		int(profile.get("battle_seed", null)),
		profile.get("commands", null)
	))

func build_passive_item_demo_replay_input_result(command_port) -> Dictionary:
	var battle_setup_result := _baseline_matchup_catalog.build_setup_result(_setup_builder, "passive_item_vs_sample")
	if not bool(battle_setup_result.get("ok", false)):
		return _record_result(battle_setup_result)
	var battle_setup = battle_setup_result.get("data", null)
	var snapshot_paths_result := _content_paths_helper.build_base_snapshot_paths(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS)
	if not bool(snapshot_paths_result.get("ok", false)):
		return _record_result(snapshot_paths_result)
	return _record_result(_replay_builder.build_passive_item_demo_replay_input_result(command_port, snapshot_paths_result, battle_setup))

func _refresh_baseline_unit_definition_ids() -> void:
	var baseline_units_result: Dictionary = _baseline_matchup_catalog.baseline_unit_definition_ids_result()
	_content_paths_helper.baseline_unit_definition_ids = baseline_units_result.get("data", PackedStringArray()) if bool(baseline_units_result.get("ok", false)) else PackedStringArray()

func _record_result(result: Dictionary) -> Dictionary:
	last_error_code = result.get("error_code", null)
	var error_message = result.get("error_message", "")
	last_error_message = "" if error_message == null else str(error_message)
	return result

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
