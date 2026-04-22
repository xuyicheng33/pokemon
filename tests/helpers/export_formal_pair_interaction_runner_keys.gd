extends SceneTree

const ScenarioRegistryScript := preload("res://tests/support/formal_pair_interaction/scenario_registry.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("EXPORT_FORMAL_PAIR_INTERACTION_RUNNER_KEYS_FAILED: missing output path")
		quit(1)
		return
	var output_path := String(args[0]).strip_edges()
	if output_path.is_empty():
		printerr("EXPORT_FORMAL_PAIR_INTERACTION_RUNNER_KEYS_FAILED: empty output path")
		quit(1)
		return
	var registry = ScenarioRegistryScript.new()
	if registry == null:
		printerr("EXPORT_FORMAL_PAIR_INTERACTION_RUNNER_KEYS_FAILED: missing scenario registry")
		quit(1)
		return
	var runners = registry.build_runners()
	if not (runners is Dictionary):
		printerr("EXPORT_FORMAL_PAIR_INTERACTION_RUNNER_KEYS_FAILED: scenario registry build_runners() must return Dictionary")
		quit(1)
		return
	var scenario_keys: Array = []
	for raw_scenario_key in runners.keys():
		var scenario_key := String(raw_scenario_key).strip_edges()
		var runner: Callable = runners.get(raw_scenario_key, Callable())
		if scenario_key.is_empty():
			printerr("EXPORT_FORMAL_PAIR_INTERACTION_RUNNER_KEYS_FAILED: empty scenario_key")
			quit(1)
			return
		if not runner.is_valid():
			printerr("EXPORT_FORMAL_PAIR_INTERACTION_RUNNER_KEYS_FAILED: invalid runner for %s" % scenario_key)
			quit(1)
			return
		scenario_keys.append(scenario_key)
	scenario_keys.sort()
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("EXPORT_FORMAL_PAIR_INTERACTION_RUNNER_KEYS_FAILED: cannot open output path: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify({"scenario_keys": scenario_keys}, "  "))
	file.flush()
	file.close()
	quit(0)
