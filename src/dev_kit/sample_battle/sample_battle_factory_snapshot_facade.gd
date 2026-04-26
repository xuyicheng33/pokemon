extends RefCounted
class_name SampleBattleFactorySnapshotFacade

const ContentPathsHelperScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_content_paths_helper.gd")

var content_paths_helper: SampleBattleFactoryContentPathsHelper = null

func content_snapshot_paths_result() -> Dictionary:
	return content_paths_helper.build_snapshot_paths(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS)

func content_snapshot_paths_for_setup_result(battle_setup) -> Dictionary:
	return content_paths_helper.build_snapshot_paths_for_setup(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS, battle_setup)

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	return content_paths_helper.collect_tres_paths_result(dir_path)

func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary:
	return content_paths_helper.collect_tres_paths_recursive_result(dir_path)
