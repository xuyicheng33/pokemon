extends RefCounted
class_name BattleCoreTestHarnessSampleHelper

const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")

var _active_sample_factories: Array = []

func build_sample_factory():
	var sample_factory = SampleBattleFactoryScript.new()
	if sample_factory == null:
		return null
	_active_sample_factories.append(sample_factory)
	return sample_factory

func dispose_sample_factories() -> void:
	for sample_factory in _active_sample_factories:
		if sample_factory != null and sample_factory.has_method("dispose"):
			sample_factory.dispose()
	_active_sample_factories.clear()

func build_sample_factory_with_overrides(
	registry_path_override: String = "",
	matchup_catalog_path_override: String = "",
	delivery_registry_path_override: String = ""
):
	var sample_factory = build_sample_factory()
	if sample_factory == null:
		return null
	var manifest_path_override := String(registry_path_override).strip_edges()
	if manifest_path_override.is_empty():
		manifest_path_override = String(matchup_catalog_path_override).strip_edges()
	if manifest_path_override.is_empty():
		manifest_path_override = String(delivery_registry_path_override).strip_edges()
	if not manifest_path_override.is_empty():
		sample_factory.configure_formal_manifest_path_override(manifest_path_override)
	return sample_factory

func unwrap_sample_factory_result(result: Dictionary, label: String):
	assert(bool(result.get("ok", false)), "SampleBattleFactory %s failed: %s" % [label, str(result.get("error_message", "unknown error"))])
	return result.get("data", null)

func build_setup_by_matchup_id(sample_factory, matchup_id: String, side_regular_skill_overrides: Dictionary = {}):
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return null
	return unwrap_sample_factory_result(
		sample_factory.build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides),
		"build_setup_by_matchup_id(%s)" % matchup_id
	)

func build_sample_setup(sample_factory, side_regular_skill_overrides: Dictionary = {}):
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return null
	return unwrap_sample_factory_result(
		sample_factory.build_sample_setup_result(side_regular_skill_overrides),
		"build_sample_setup"
	)

func build_demo_replay_input(sample_factory, command_port, side_regular_skill_overrides: Dictionary = {}):
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return null
	return unwrap_sample_factory_result(
		sample_factory.build_demo_replay_input_result(command_port, side_regular_skill_overrides),
		"build_demo_replay_input"
	)

func build_passive_item_demo_replay_input(sample_factory, command_port):
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return null
	return unwrap_sample_factory_result(
		sample_factory.build_passive_item_demo_replay_input_result(command_port),
		"build_passive_item_demo_replay_input"
	)

func build_formal_character_ids(sample_factory) -> PackedStringArray:
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return PackedStringArray()
	return unwrap_sample_factory_result(sample_factory.formal_character_ids_result(), "formal_character_ids")

func build_formal_unit_definition_ids(sample_factory) -> PackedStringArray:
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return PackedStringArray()
	return unwrap_sample_factory_result(sample_factory.formal_unit_definition_ids_result(), "formal_unit_definition_ids")

func build_formal_character_setup(sample_factory, character_id: String, side_regular_skill_overrides: Dictionary = {}):
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return null
	return unwrap_sample_factory_result(
		sample_factory.build_formal_character_setup_result(character_id, side_regular_skill_overrides),
		"build_formal_character_setup(%s)" % character_id
	)

func build_formal_pair_surface_cases(sample_factory) -> Array:
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return []
	return unwrap_sample_factory_result(sample_factory.formal_pair_surface_cases_result(), "formal_pair_surface_cases")

func build_formal_pair_interaction_cases(sample_factory) -> Array:
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return []
	return unwrap_sample_factory_result(sample_factory.formal_pair_interaction_cases_result(), "formal_pair_interaction_cases")

func collect_tres_paths_recursive(sample_factory, dir_path: String) -> Array[String]:
	if sample_factory == null:
		assert(false, "SampleBattleFactory init failed")
		return []
	return unwrap_sample_factory_result(
		sample_factory.collect_tres_paths_recursive_result(dir_path),
		"collect_tres_paths_recursive(%s)" % dir_path
	)

func build_content_snapshot_paths(sample_factory) -> Dictionary:
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	var snapshot_result: Dictionary = sample_factory.content_snapshot_paths_result()
	if not bool(snapshot_result.get("ok", false)):
		return {"error": str(snapshot_result.get("error_message", "content snapshot path build failed"))}
	return {"paths": snapshot_result.get("data", PackedStringArray())}

func build_content_snapshot_paths_for_setup(sample_factory, battle_setup) -> Dictionary:
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	if battle_setup == null:
		return {"error": "battle_setup is required"}
	var snapshot_result: Dictionary = sample_factory.content_snapshot_paths_for_setup_result(battle_setup)
	if not bool(snapshot_result.get("ok", false)):
		return {"error": str(snapshot_result.get("error_message", "content snapshot path build failed"))}
	return {"paths": snapshot_result.get("data", PackedStringArray())}

func build_loaded_content_index(sample_factory):
	var content_index = BattleContentIndexScript.new()
	var snapshot_paths_payload := build_content_snapshot_paths(sample_factory)
	assert(not snapshot_paths_payload.has("error"), "Content snapshot path build failed: %s" % str(snapshot_paths_payload.get("error", "unknown error")))
	var loaded: bool = content_index.load_snapshot(snapshot_paths_payload.get("paths", PackedStringArray()))
	assert(loaded, "Content snapshot load failed: %s" % content_index.last_error_message)
	return content_index

func build_loaded_content_index_for_setup(sample_factory, battle_setup):
	var content_index = BattleContentIndexScript.new()
	var snapshot_paths_payload := build_content_snapshot_paths_for_setup(sample_factory, battle_setup)
	assert(not snapshot_paths_payload.has("error"), "Content snapshot path build failed: %s" % str(snapshot_paths_payload.get("error", "unknown error")))
	var loaded: bool = content_index.load_snapshot(snapshot_paths_payload.get("paths", PackedStringArray()))
	assert(loaded, "Content snapshot load failed: %s" % content_index.last_error_message)
	return content_index
