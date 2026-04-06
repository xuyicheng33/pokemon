extends RefCounted
class_name SampleBattleFactory

const ContentPathsHelperScript := preload("res://src/composition/sample_battle_factory_content_paths_helper.gd")
const MatchupCatalogScript := preload("res://src/composition/sample_battle_factory_matchup_catalog.gd")
const ReplayBuilderScript := preload("res://src/composition/sample_battle_factory_replay_builder.gd")
const RegistryHelperScript := preload("res://src/composition/sample_battle_factory_registry_helper.gd")
const SetupBuilderScript := preload("res://src/composition/sample_battle_factory_setup_builder.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var _content_paths_helper = ContentPathsHelperScript.new()
var _matchup_catalog = MatchupCatalogScript.new()
var _replay_builder = ReplayBuilderScript.new()
var _registry_helper = RegistryHelperScript.new()
var _setup_builder = SetupBuilderScript.new()
var last_error_code: Variant = null
var last_error_message: String = ""

func configure_registry_path_override(path: String) -> void:
	_registry_helper.registry_path_override = path
	_content_paths_helper.registry_path_override = path

func configure_matchup_catalog_path_override(path: String) -> void:
	_matchup_catalog.catalog_path_override = path

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

func build_setup_from_side_specs(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Variant:
	var result := build_setup_from_side_specs_result(p1_side_spec, p2_side_spec)
	if not bool(result.get("ok", false)):
		return null
	return result.get("data", null)

func build_setup_from_side_specs_result(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Dictionary:
	var battle_setup = _setup_builder.build_setup_from_side_specs(p1_side_spec, p2_side_spec)
	if battle_setup == null:
		return _record_result(_registry_helper.error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build setup from side specs"
		))
	return _record_result(_registry_helper.ok_result(battle_setup))

func content_snapshot_paths_result() -> Dictionary:
	return _record_result(_content_paths_helper.build_snapshot_paths(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS))

func content_snapshot_paths_for_setup_result(battle_setup) -> Dictionary:
	return _record_result(_content_paths_helper.build_snapshot_paths_for_setup(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS, battle_setup))

func content_snapshot_paths() -> PackedStringArray:
	var result := content_snapshot_paths_result()
	if not bool(result.get("ok", false)):
		return PackedStringArray()
	return result.get("data", PackedStringArray())

func content_snapshot_paths_for_setup(battle_setup) -> PackedStringArray:
	var result := content_snapshot_paths_for_setup_result(battle_setup)
	if not bool(result.get("ok", false)):
		return PackedStringArray()
	return result.get("data", PackedStringArray())

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	return _record_result(_content_paths_helper.collect_tres_paths_result(dir_path))

func collect_tres_paths(dir_path: String) -> Array[String]:
	var result := collect_tres_paths_result(dir_path)
	if not bool(result.get("ok", false)):
		return []
	return result.get("data", [])

func collect_tres_paths_recursive(dir_path: String) -> Array[String]:
	var result := collect_tres_paths_recursive_result(dir_path)
	if not bool(result.get("ok", false)):
		return []
	return result.get("data", [])

func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary:
	return _record_result(_content_paths_helper.collect_tres_paths_recursive_result(dir_path))

func build_setup_by_matchup_id(matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Variant:
	var result := build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides)
	if not bool(result.get("ok", false)):
		return null
	return result.get("data", null)

func build_setup_by_matchup_id_result(matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return _record_result(_matchup_catalog.build_setup_result(_setup_builder, matchup_id, side_regular_skill_overrides))

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
		return _record_result(_registry_helper.error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build matchup setup"
		))
	return _record_result(_registry_helper.ok_result(battle_setup))

func formal_character_ids() -> PackedStringArray:
	var result := formal_character_ids_result()
	if not bool(result.get("ok", false)):
		return PackedStringArray()
	return result.get("data", PackedStringArray())

func formal_character_ids_result() -> Dictionary:
	return _formal_ids_result("character_id")

func formal_unit_definition_ids() -> PackedStringArray:
	var result := formal_unit_definition_ids_result()
	if not bool(result.get("ok", false)):
		return PackedStringArray()
	return result.get("data", PackedStringArray())

func formal_unit_definition_ids_result() -> Dictionary:
	return _formal_ids_result("unit_definition_id")

func _formal_ids_result(entry_key: String) -> Dictionary:
	var ids := PackedStringArray()
	var entries_result := _registry_helper.load_entries_result()
	if not bool(entries_result.get("ok", false)):
		return _record_result(entries_result)
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		var entry_id := str(entry.get(entry_key, "")).strip_edges()
		if entry_id.is_empty():
			continue
		ids.append(entry_id)
	return _record_result(_registry_helper.ok_result(ids))

func build_formal_character_setup(character_id: String, side_regular_skill_overrides: Dictionary = {}) -> Variant:
	var result := build_formal_character_setup_result(character_id, side_regular_skill_overrides)
	if not bool(result.get("ok", false)):
		return null
	return result.get("data", null)

func build_formal_character_setup_result(character_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var entry_result := _registry_helper.find_entry_result(character_id)
	if not bool(entry_result.get("ok", false)):
		return _record_result(entry_result)
	var entry: Dictionary = entry_result.get("data", {})
	var matchup_id := str(entry.get("formal_setup_matchup_id", "")).strip_edges()
	if matchup_id.is_empty():
		return _record_result(_registry_helper.error_result(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"SampleBattleFactory registry[%s] missing formal_setup_matchup_id" % character_id
		))
	var setup_result := build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides)
	if not bool(setup_result.get("ok", false)):
		return _record_result(_registry_helper.error_result(
			str(setup_result.get("error_code", ErrorCodesScript.INVALID_BATTLE_SETUP)),
			"SampleBattleFactory registry[%s] references missing formal setup matchup: %s" % [
				character_id,
				matchup_id,
			]
		))
	return _record_result(_registry_helper.ok_result(setup_result.get("data", null)))

func formal_pair_smoke_cases() -> Array:
	return _matchup_catalog.formal_pair_smoke_cases()

func formal_pair_surface_cases() -> Array:
	return _matchup_catalog.formal_pair_surface_cases()

func formal_pair_interaction_cases() -> Array:
	return _matchup_catalog.formal_pair_interaction_cases()

func build_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("sample_default", side_regular_skill_overrides)

func build_demo_replay_input(command_port, side_regular_skill_overrides: Dictionary = {}) -> Variant:
	var battle_setup = build_sample_setup(side_regular_skill_overrides)
	var snapshot_paths_result := content_snapshot_paths_for_setup_result(battle_setup)
	return _replay_builder.build_demo_replay_input(command_port, snapshot_paths_result, battle_setup)

func build_passive_item_demo_replay_input(command_port) -> Variant:
	var battle_setup = build_setup_by_matchup_id("passive_item_vs_sample")
	var snapshot_paths_result := content_snapshot_paths_for_setup_result(battle_setup)
	return _replay_builder.build_passive_item_demo_replay_input(command_port, snapshot_paths_result, battle_setup)

func _record_result(result: Dictionary) -> Dictionary:
	last_error_code = result.get("error_code", null)
	var error_message = result.get("error_message", "")
	last_error_message = "" if error_message == null else str(error_message)
	return result
