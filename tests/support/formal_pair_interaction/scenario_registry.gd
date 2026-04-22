extends RefCounted
class_name FormalPairInteractionScenarioRegistry

const CASES_DIR_PATH := "res://tests/support/formal_pair_interaction"
const CASE_FILE_SUFFIX := "_cases.gd"

var _case_instances: Array = []

func build_runners() -> Dictionary:
	var runners: Dictionary = {}
	_case_instances.clear()
	var case_script_paths := _case_script_paths()
	if case_script_paths.is_empty():
		printerr("FormalPairInteractionScenarioRegistry discovered no case scripts under %s" % CASES_DIR_PATH)
		return {}
	for raw_case_script_path in case_script_paths:
		var case_script_path := String(raw_case_script_path).strip_edges()
		var loaded_script = load(case_script_path)
		if loaded_script == null or not loaded_script.can_instantiate():
			printerr("FormalPairInteractionScenarioRegistry failed to load case script: %s" % case_script_path)
			return {}
		var cases = loaded_script.new()
		if cases == null or not cases.has_method("build_runners"):
			printerr("FormalPairInteractionScenarioRegistry case script missing build_runners(): %s" % case_script_path)
			return {}
		_case_instances.append(cases)
		var case_runners = cases.build_runners()
		if not (case_runners is Dictionary):
			printerr("FormalPairInteractionScenarioRegistry case script build_runners() must return Dictionary: %s" % case_script_path)
			return {}
		for raw_scenario_key in case_runners.keys():
			var scenario_key := String(raw_scenario_key).strip_edges()
			var runner: Callable = case_runners.get(raw_scenario_key, Callable())
			if scenario_key.is_empty():
				printerr("FormalPairInteractionScenarioRegistry found empty scenario_key from %s" % case_script_path)
				return {}
			if not runner.is_valid():
				printerr("FormalPairInteractionScenarioRegistry found invalid runner for %s in %s" % [scenario_key, case_script_path])
				return {}
			if runners.has(scenario_key):
				printerr("FormalPairInteractionScenarioRegistry duplicated scenario_key: %s" % scenario_key)
				return {}
			runners[scenario_key] = runner
	return runners

func _case_script_paths() -> Array:
	var dir := DirAccess.open(CASES_DIR_PATH)
	if dir == null:
		return []
	var case_script_paths: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if dir.current_is_dir() or file_name.begins_with(".") or not file_name.ends_with(CASE_FILE_SUFFIX):
			file_name = dir.get_next()
			continue
		case_script_paths.append("%s/%s" % [CASES_DIR_PATH, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()
	case_script_paths.sort()
	return case_script_paths
