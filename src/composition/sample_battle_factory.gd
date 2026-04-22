extends RefCounted
class_name SampleBattleFactory

const BaselineMatchupCatalogScript := preload("res://src/composition/sample_battle_factory_baseline_matchup_catalog.gd")
const ContentPathsHelperScript := preload("res://src/composition/sample_battle_factory_content_paths_helper.gd")
const DemoInputBuilderScript := preload("res://src/composition/sample_battle_factory_demo_input_builder.gd")
const DemoCatalogScript := preload("res://src/composition/sample_battle_factory_demo_catalog.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")
const FormalAccessScript := preload("res://src/composition/sample_battle_factory_formal_access.gd")
const MatchupCatalogScript := preload("res://src/composition/sample_battle_factory_matchup_catalog.gd")
const SetupAccessScript := preload("res://src/composition/sample_battle_factory_setup_access.gd")

var _catalog_access: SampleBattleFactoryBaselineMatchupCatalog = BaselineMatchupCatalogScript.new()
var _snapshot_access: SampleBattleFactoryContentPathsHelper = ContentPathsHelperScript.new()
var _demo_input_builder: SampleBattleFactoryDemoInputBuilder = DemoInputBuilderScript.new()
var _demo_catalog: SampleBattleFactoryDemoCatalog = DemoCatalogScript.new()
var _formal_access: SampleBattleFactoryFormalAccess = FormalAccessScript.new()
var _formal_matchup_catalog: SampleBattleFactoryFormalMatchupCatalog = MatchupCatalogScript.new()
var _setup_access: SampleBattleFactorySetupAccess = SetupAccessScript.new()
var last_error_code: Variant = null
var last_error_message: String = ""
var _disposed: bool = false

func _init() -> void:
	_setup_access.baseline_matchup_catalog = _catalog_access
	_setup_access.formal_matchup_catalog = _formal_matchup_catalog
	_snapshot_access.formal_access = _formal_access
	_demo_input_builder.baseline_matchup_catalog = _catalog_access
	_demo_input_builder.content_paths_helper = _snapshot_access
	_demo_input_builder.demo_catalog = _demo_catalog
	_demo_input_builder.setup_access = _setup_access
	_formal_access.formal_matchup_catalog = _formal_matchup_catalog
	_formal_access.setup_access = _setup_access
	_catalog_access.snapshot_access = _snapshot_access
	_catalog_access.demo_catalog = _demo_catalog
	_catalog_access.formal_access = _formal_access
	_catalog_access.formal_matchup_catalog = _formal_matchup_catalog
	_catalog_access.refresh_baseline_unit_definition_ids()

func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	if _setup_access != null:
		_setup_access.baseline_matchup_catalog = null
		_setup_access.formal_matchup_catalog = null
	if _snapshot_access != null:
		_snapshot_access.formal_access = null
	if _demo_input_builder != null:
		_demo_input_builder.baseline_matchup_catalog = null
		_demo_input_builder.content_paths_helper = null
		_demo_input_builder.demo_catalog = null
		_demo_input_builder.setup_access = null
	if _formal_access != null:
		_formal_access.formal_matchup_catalog = null
		_formal_access.setup_access = null
	if _catalog_access != null:
		_catalog_access.snapshot_access = null
		_catalog_access.demo_catalog = null
		_catalog_access.formal_access = null
		_catalog_access.formal_matchup_catalog = null
	_catalog_access = null
	_snapshot_access = null
	_demo_input_builder = null
	_demo_catalog = null
	_formal_access = null
	_formal_matchup_catalog = null
	_setup_access = null
	ErrorStateHelperScript.clear(self)

func configure_registry_path_override(path: String) -> void:
	_catalog_access.configure_registry_path_override(path)

func configure_baseline_matchup_catalog_path_override(path: String) -> void:
	_catalog_access.configure_baseline_matchup_catalog_path_override(path)

func configure_matchup_catalog_path_override(path: String) -> void:
	_catalog_access.configure_matchup_catalog_path_override(path)

func configure_delivery_registry_path_override(path: String) -> void:
	_catalog_access.configure_delivery_registry_path_override(path)

func configure_formal_manifest_path_override(path: String) -> void:
	_catalog_access.configure_formal_manifest_path_override(path)

func configure_demo_catalog_path_override(path: String) -> void:
	_catalog_access.configure_demo_catalog_path_override(path)

func default_demo_profile_id() -> String:
	var result := default_demo_profile_id_result()
	if not bool(result.get("ok", false)):
		return ""
	return String(result.get("data", "")).strip_edges()

func default_demo_profile_id_result() -> Dictionary:
	return _record_result(_demo_catalog.default_profile_id_result())

func demo_profile_result(profile_id: String) -> Dictionary:
	return _record_result(_demo_catalog.profile_result(profile_id))

func demo_profile_ids_result() -> Dictionary:
	return _record_result(_demo_catalog.profile_ids_result())

func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func build_side_spec(
	unit_definition_ids: PackedStringArray,
	starting_index: int = 0,
	regular_skill_loadout_overrides: Dictionary = {}
) -> Dictionary:
	return _setup_access.build_side_spec(unit_definition_ids, starting_index, regular_skill_loadout_overrides)

func build_setup_from_side_specs_result(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Dictionary:
	return _record_result(_setup_access.build_setup_from_side_specs_result(p1_side_spec, p2_side_spec))

func content_snapshot_paths_result() -> Dictionary:
	return _record_result(_snapshot_access.build_snapshot_paths(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS))

func content_snapshot_paths_for_setup_result(battle_setup) -> Dictionary:
	return _record_result(_snapshot_access.build_snapshot_paths_for_setup(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS, battle_setup))

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	return _record_result(_snapshot_access.collect_tres_paths_result(dir_path))

func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary:
	return _record_result(_snapshot_access.collect_tres_paths_recursive_result(dir_path))

func build_setup_by_matchup_id_result(matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return _record_result(_setup_access.build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides))

func available_matchups_result() -> Dictionary:
	return _record_result(_catalog_access.available_matchups_result())

func build_matchup_setup_result(
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary = {},
	p1_starting_index: int = 0,
	p2_starting_index: int = 0
) -> Dictionary:
	return _record_result(_setup_access.build_matchup_setup_result(
		p1_unit_definition_ids,
		p2_unit_definition_ids,
		side_regular_skill_overrides,
		p1_starting_index,
		p2_starting_index
	))

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
	return _record_result(_setup_access.build_sample_setup_result(side_regular_skill_overrides))

func build_demo_replay_input_result(command_port, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return _record_result(_demo_input_builder.build_demo_replay_input_result(
		command_port,
		side_regular_skill_overrides
	))

func build_demo_replay_input_for_profile_result(command_port, demo_profile_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return _record_result(_demo_input_builder.build_demo_replay_input_for_profile_result(
		command_port,
		demo_profile_id,
		side_regular_skill_overrides
	))

func build_passive_item_demo_replay_input_result(command_port) -> Dictionary:
	return _record_result(_demo_input_builder.build_passive_item_demo_replay_input_result(command_port))

func _record_result(result: Dictionary) -> Dictionary:
	ErrorStateHelperScript.capture_envelope(self, result)
	return result
