extends RefCounted
class_name SampleBattleFactoryContentPathsHelper

const BaseSnapshotPathsServiceScript := preload("res://src/composition/sample_battle_factory_base_snapshot_paths_service.gd")
const FormalSnapshotPathsServiceScript := preload("res://src/composition/sample_battle_factory_formal_snapshot_paths_service.gd")
const BASE_CONTENT_SNAPSHOT_DIRS = BaseSnapshotPathsServiceScript.BASE_CONTENT_SNAPSHOT_DIRS

var registry_path_override: String = ""
var baseline_unit_definition_ids: PackedStringArray = PackedStringArray()
var _base_snapshot_paths_service = BaseSnapshotPathsServiceScript.new()
var _formal_snapshot_paths_service = FormalSnapshotPathsServiceScript.new()

func _init() -> void:
	_formal_snapshot_paths_service.base_snapshot_paths_service = _base_snapshot_paths_service

func build_snapshot_paths(base_dirs: Array) -> Dictionary:
	_sync_formal_snapshot_paths_service()
	return _formal_snapshot_paths_service.build_snapshot_paths_result(base_dirs)

func build_base_snapshot_paths(base_dirs: Array) -> Dictionary:
	return _base_snapshot_paths_service.build_base_snapshot_paths(base_dirs)

func build_snapshot_paths_for_setup(base_dirs: Array, battle_setup) -> Dictionary:
	_sync_formal_snapshot_paths_service()
	return _formal_snapshot_paths_service.build_snapshot_paths_for_setup_result(base_dirs, battle_setup)

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	return _base_snapshot_paths_service.collect_tres_paths_result(dir_path)

func collect_tres_paths_recursive(dir_path: String) -> Array[String]:
	var result := collect_tres_paths_recursive_result(dir_path)
	if not bool(result.get("ok", false)):
		return []
	return result.get("data", [])

func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary:
	return _base_snapshot_paths_service.collect_tres_paths_recursive_result(dir_path)

func _sync_formal_snapshot_paths_service() -> void:
	_formal_snapshot_paths_service.registry_path_override = registry_path_override
	_formal_snapshot_paths_service.baseline_unit_definition_ids = baseline_unit_definition_ids
