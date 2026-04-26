extends RefCounted
class_name SampleBattleFactory

const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")
const FormalAccessScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_formal_access.gd")
const RuntimeGraphScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_runtime_graph.gd")

var _graph: SampleBattleFactoryRuntimeGraph = RuntimeGraphScript.new()
var last_error_code: Variant = null
var last_error_message: String = ""
var _disposed: bool = false

func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	if _graph != null:
		_graph.dispose()
	_graph = null
	ErrorStateHelperScript.clear(self)

func configure_registry_path_override(path: String) -> void: _graph.configure_registry_path_override(path)
func configure_baseline_matchup_catalog_path_override(path: String) -> void: _graph.configure_baseline_matchup_catalog_path_override(path)
func configure_matchup_catalog_path_override(path: String) -> void: _graph.configure_matchup_catalog_path_override(path)
func configure_delivery_registry_path_override(path: String) -> void: _graph.configure_registry_path_override(path)
func configure_formal_manifest_path_override(path: String) -> void: _graph.configure_registry_path_override(path)
func configure_demo_catalog_path_override(path: String) -> void: _graph.configure_demo_catalog_path_override(path)

func default_demo_profile_id() -> String:
	var result := default_demo_profile_id_result()
	return String(result.get("data", "")).strip_edges() if bool(result.get("ok", false)) else ""

func default_demo_profile_id_result() -> Dictionary: return _record_result(_graph.demo_facade.default_demo_profile_id_result())
func demo_profile_result(profile_id: String) -> Dictionary: return _record_result(_graph.demo_facade.demo_profile_result(profile_id))
func demo_profile_ids_result() -> Dictionary: return _record_result(_graph.demo_facade.demo_profile_ids_result())
func error_state() -> Dictionary: return ErrorStateHelperScript.error_state(self)
func build_side_spec(unit_definition_ids: PackedStringArray, starting_index: int = 0, regular_skill_loadout_overrides: Dictionary = {}) -> Dictionary: return _graph.setup_facade.build_side_spec(unit_definition_ids, starting_index, regular_skill_loadout_overrides)
func build_setup_from_side_specs_result(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Dictionary: return _record_result(_graph.setup_facade.build_setup_from_side_specs_result(p1_side_spec, p2_side_spec))
func content_snapshot_paths_result() -> Dictionary: return _record_result(_graph.snapshot_facade.content_snapshot_paths_result())
func content_snapshot_paths_for_setup_result(battle_setup) -> Dictionary: return _record_result(_graph.snapshot_facade.content_snapshot_paths_for_setup_result(battle_setup))
func collect_tres_paths_result(dir_path: String) -> Dictionary: return _record_result(_graph.snapshot_facade.collect_tres_paths_result(dir_path))
func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary: return _record_result(_graph.snapshot_facade.collect_tres_paths_recursive_result(dir_path))
func build_setup_by_matchup_id_result(matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary: return _record_result(_graph.setup_facade.build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides))
func available_matchups_result() -> Dictionary: return _record_result(_graph.catalog_facade.available_matchups_result())
func build_matchup_setup_result(p1_unit_definition_ids: PackedStringArray, p2_unit_definition_ids: PackedStringArray, side_regular_skill_overrides: Dictionary = {}, p1_starting_index: int = 0, p2_starting_index: int = 0) -> Dictionary: return _record_result(_graph.setup_facade.build_matchup_setup_result(p1_unit_definition_ids, p2_unit_definition_ids, side_regular_skill_overrides, p1_starting_index, p2_starting_index))
func formal_character_ids_result() -> Dictionary: return _record_result(_graph.catalog_facade.formal_character_ids_result())
func formal_unit_definition_ids_result() -> Dictionary: return _record_result(_graph.catalog_facade.formal_unit_definition_ids_result())
func build_formal_character_setup_result(character_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary: return _record_result(_graph.setup_facade.build_formal_character_setup_result(character_id, side_regular_skill_overrides))
func formal_pair_smoke_cases_result() -> Dictionary: return _record_result(_graph.catalog_facade.formal_pair_smoke_cases_result())
func formal_pair_surface_cases_result() -> Dictionary: return _record_result(_graph.catalog_facade.formal_pair_surface_cases_result())
func formal_pair_interaction_cases_result() -> Dictionary: return _record_result(_graph.catalog_facade.formal_pair_interaction_cases_result())
func build_sample_setup_result(side_regular_skill_overrides: Dictionary = {}) -> Dictionary: return _record_result(_graph.setup_facade.build_sample_setup_result(side_regular_skill_overrides))
func build_demo_replay_input_result(command_port, side_regular_skill_overrides: Dictionary = {}) -> Dictionary: return _record_result(_graph.demo_facade.build_demo_replay_input_result(command_port, side_regular_skill_overrides))
func build_demo_replay_input_for_profile_result(command_port, demo_profile_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary: return _record_result(_graph.demo_facade.build_demo_replay_input_for_profile_result(command_port, demo_profile_id, side_regular_skill_overrides))
func build_passive_item_demo_replay_input_result(command_port) -> Dictionary: return _record_result(_graph.demo_facade.build_passive_item_demo_replay_input_result(command_port))

func _record_result(result: Dictionary) -> Dictionary:
	ErrorStateHelperScript.capture_envelope(self, result)
	return result
