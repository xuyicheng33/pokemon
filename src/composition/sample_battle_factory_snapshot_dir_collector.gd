extends RefCounted
class_name SampleBattleFactorySnapshotDirCollector

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	var dir_access := DirAccess.open(dir_path)
	if dir_access == null:
		return _error_result("SampleBattleFactory missing snapshot dir: %s" % dir_path)
	var paths: Array[String] = []
	for raw_file_name in dir_access.get_files():
		var file_name := String(raw_file_name)
		if file_name.get_extension() != "tres":
			continue
		paths.append("%s/%s" % [dir_path, file_name])
	paths.sort()
	return _ok_result(paths)

func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary:
	var dir_access := DirAccess.open(dir_path)
	if dir_access == null:
		return _error_result("SampleBattleFactory missing snapshot dir: %s" % dir_path)
	var paths: Array[String] = []
	for raw_subdir_name in dir_access.get_directories():
		var child_result := collect_tres_paths_recursive_result("%s/%s" % [dir_path, String(raw_subdir_name)])
		if not bool(child_result.get("ok", false)):
			return child_result
		paths.append_array(child_result.get("data", []))
	for raw_file_name in dir_access.get_files():
		var file_name := String(raw_file_name)
		if file_name.get_extension() != "tres":
			continue
		paths.append("%s/%s" % [dir_path, file_name])
	paths.sort()
	return _ok_result(paths)

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
		"error_message": error_message,
	}
