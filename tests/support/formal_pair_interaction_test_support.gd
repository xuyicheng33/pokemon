extends RefCounted
class_name FormalPairInteractionTestSupport

const ScenarioRegistryScript := preload("res://tests/support/formal_pair_interaction/scenario_registry.gd")

var _registry = ScenarioRegistryScript.new()
var _runners: Dictionary = _registry.build_runners()

func validate_case_catalog(harness, interaction_cases: Array) -> Dictionary:
	var scenario_case_counts: Dictionary = {}
	var seen_test_names: Dictionary = {}
	for raw_case_spec in interaction_cases:
		if not (raw_case_spec is Dictionary):
			return harness.fail_result("formal pair interaction case must be Dictionary")
		var test_name := String(raw_case_spec.get("test_name", "")).strip_edges()
		if test_name.is_empty():
			return harness.fail_result("formal pair interaction case missing test_name")
		if seen_test_names.has(test_name):
			return harness.fail_result("formal pair interaction duplicated test_name: %s" % test_name)
		var scenario_key := String(raw_case_spec.get("scenario_key", "")).strip_edges()
		if scenario_key.is_empty():
			return harness.fail_result("formal pair interaction case missing scenario_key")
		if not _is_positive_whole_number(raw_case_spec.get("battle_seed", null)):
			return harness.fail_result("formal pair interaction case missing positive integer battle_seed")
		if not _runners.has(scenario_key):
			return harness.fail_result("formal pair interaction unsupported scenario_key: %s" % scenario_key)
		seen_test_names[test_name] = true
		scenario_case_counts[scenario_key] = int(scenario_case_counts.get(scenario_key, 0)) + 1
	for scenario_key in _runners.keys():
		if int(scenario_case_counts.get(String(scenario_key), 0)) != 2:
			return harness.fail_result("formal pair interaction scenario_key must generate exactly two directed cases: %s" % String(scenario_key))
	return harness.pass_result()

func run_case(harness, case_spec: Dictionary) -> Dictionary:
	var scenario_key := String(case_spec.get("scenario_key", "")).strip_edges()
	var runner: Callable = _runners.get(scenario_key, Callable())
	if not runner.is_valid():
		return harness.fail_result("formal pair interaction unknown scenario_key: %s" % scenario_key)
	return runner.call(harness, case_spec)

func _is_positive_whole_number(value) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return numeric_value > 0.0 and is_equal_approx(numeric_value, floor(numeric_value))
