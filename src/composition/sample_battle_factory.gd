extends RefCounted
class_name SampleBattleFactory

const BaselineMatchupCatalogScript := preload("res://src/composition/sample_battle_factory_baseline_matchup_catalog.gd")
const ContentPathsHelperScript := preload("res://src/composition/sample_battle_factory_content_paths_helper.gd")
const DemoInputBuilderScript := preload("res://src/composition/sample_battle_factory_demo_input_builder.gd")
const DeliveryRegistryLoaderScript := preload("res://src/composition/sample_battle_factory_delivery_registry_loader.gd")
const DemoCatalogScript := preload("res://src/composition/sample_battle_factory_demo_catalog.gd")
const FormalAccessScript := preload("res://src/composition/sample_battle_factory_formal_access.gd")
const MatchupCatalogScript := preload("res://src/composition/sample_battle_factory_matchup_catalog.gd")
const ReplayBuilderScript := preload("res://src/composition/sample_battle_factory_replay_builder.gd")
const RuntimeRegistryLoaderScript := preload("res://src/composition/sample_battle_factory_runtime_registry_loader.gd")
const SetupBuilderScript := preload("res://src/composition/sample_battle_factory_setup_builder.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var _baseline_matchup_catalog = BaselineMatchupCatalogScript.new()
var _content_paths_helper = ContentPathsHelperScript.new()
var _demo_input_builder = DemoInputBuilderScript.new()
var _delivery_registry_loader = DeliveryRegistryLoaderScript.new()
var _demo_catalog = DemoCatalogScript.new()
var _formal_access = FormalAccessScript.new()
var _formal_matchup_catalog = MatchupCatalogScript.new()
var _replay_builder = ReplayBuilderScript.new()
var _runtime_registry_loader = RuntimeRegistryLoaderScript.new()
var _setup_builder = SetupBuilderScript.new()
var last_error_code: Variant = null
var last_error_message: String = ""

func _init() -> void:
	_demo_input_builder.baseline_matchup_catalog = _baseline_matchup_catalog
	_demo_input_builder.content_paths_helper = _content_paths_helper
	_demo_input_builder.demo_catalog = _demo_catalog
	_demo_input_builder.replay_builder = _replay_builder
	_formal_access.delivery_registry_loader = _delivery_registry_loader
	_formal_access.formal_matchup_catalog = _formal_matchup_catalog
	_formal_access.runtime_registry_loader = _runtime_registry_loader
	_formal_access.setup_builder = _setup_builder
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
	var result := default_demo_profile_id_result()
	if not bool(result.get("ok", false)):
		return ""
	return String(result.get("data", "")).strip_edges()

func default_demo_profile_id_result() -> Dictionary:
	return _record_result(_demo_catalog.default_profile_id_result())

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
	return _record_result(_formal_access.formal_ids_result("character_id"))

func formal_unit_definition_ids_result() -> Dictionary:
	return _record_result(_formal_access.formal_ids_result("unit_definition_id"))

func build_formal_character_setup_result(character_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return _record_result(_formal_access.build_formal_character_setup_result(character_id, side_regular_skill_overrides))

func formal_pair_smoke_cases_result() -> Dictionary:
	return _record_result(_formal_access.formal_pair_smoke_cases_result())

func formal_pair_surface_cases_result() -> Dictionary:
	return _record_result(_formal_access.formal_pair_surface_cases_result())

func formal_pair_interaction_cases_result() -> Dictionary:
	return _record_result(_formal_access.formal_pair_interaction_cases_result())

func build_sample_setup_result(side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return _record_result(_baseline_matchup_catalog.build_setup_result(_setup_builder, "sample_default", side_regular_skill_overrides))

func build_demo_replay_input_result(command_port, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return _record_result(_demo_input_builder.build_demo_replay_input_result(
		self,
		command_port,
		side_regular_skill_overrides
	))

func build_demo_replay_input_for_profile_result(command_port, demo_profile_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return _record_result(_demo_input_builder.build_demo_replay_input_for_profile_result(
		self,
		command_port,
		demo_profile_id,
		side_regular_skill_overrides
	))

func build_passive_item_demo_replay_input_result(command_port) -> Dictionary:
	return _record_result(_demo_input_builder.build_passive_item_demo_replay_input_result(self, command_port))

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
