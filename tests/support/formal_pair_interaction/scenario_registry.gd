extends RefCounted
class_name FormalPairInteractionScenarioRegistry

const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")

const CASES_DIR := "res://tests/support/formal_pair_interaction"

func build_runners() -> Dictionary:
	var case_instances := _load_case_instances()
	var runners: Dictionary = {}
	for scenario_key in _scenario_keys_from_manifest():
		for method_name in _runner_method_names(scenario_key):
			if runners.has(scenario_key):
				break
			for instance in case_instances:
				if instance.has_method(method_name):
					runners[scenario_key] = Callable(instance, method_name)
					break
	return runners

func _runner_method_names(scenario_key: String) -> PackedStringArray:
	var method_names := PackedStringArray(["run_%s" % scenario_key])
	var parts := scenario_key.split("_", false, 2)
	if parts.size() == 3:
		method_names.append("run_%s_vs_%s_%s" % [parts[0], parts[1], parts[2]])
	return method_names

func _scenario_keys_from_manifest() -> PackedStringArray:
	var manifest = FormalCharacterManifestScript.new()
	var catalog_result := manifest.build_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return PackedStringArray()
	var seen: Dictionary = {}
	var scenario_keys := PackedStringArray()
	for raw_case in catalog_result.get("data", {}).get("pair_interaction_cases", []):
		if not (raw_case is Dictionary):
			continue
		var scenario_key := String(raw_case.get("scenario_key", "")).strip_edges()
		if scenario_key.is_empty() or seen.has(scenario_key):
			continue
		seen[scenario_key] = true
		scenario_keys.append(scenario_key)
	return scenario_keys

func _load_case_instances() -> Array:
	var case_instances: Array = []
	var dir = DirAccess.open(CASES_DIR)
	if dir == null:
		return case_instances
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with("_cases.gd"):
			var script_path := "%s/%s" % [CASES_DIR, file_name]
			var script = load(script_path)
			if script is Script and script.can_instantiate():
				case_instances.append(script.new())
		file_name = dir.get_next()
	dir.list_dir_end()
	return case_instances
