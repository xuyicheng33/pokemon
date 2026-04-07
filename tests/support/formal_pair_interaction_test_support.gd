extends RefCounted
class_name FormalPairInteractionTestSupport

const ScenarioRegistryScript := preload("res://tests/support/formal_pair_interaction/scenario_registry.gd")

var _registry = ScenarioRegistryScript.new()
var _runners: Dictionary = _registry.build_runners()

func validate_case_catalog(harness, interaction_cases: Array) -> Dictionary:
	var seen_scenario_ids: Dictionary = {}
	for raw_case_spec in interaction_cases:
		if not (raw_case_spec is Dictionary):
			return harness.fail_result("formal pair interaction case must be Dictionary")
		var scenario_id := String(raw_case_spec.get("scenario_id", "")).strip_edges()
		if scenario_id.is_empty():
			return harness.fail_result("formal pair interaction case missing scenario_id")
		if seen_scenario_ids.has(scenario_id):
			return harness.fail_result("formal pair interaction duplicated scenario_id: %s" % scenario_id)
		if not _is_positive_whole_number(raw_case_spec.get("battle_seed", null)):
			return harness.fail_result("formal pair interaction case missing positive integer battle_seed")
		if not _runners.has(scenario_id):
			return harness.fail_result("formal pair interaction unsupported scenario_id: %s" % scenario_id)
		seen_scenario_ids[scenario_id] = true
	for scenario_id in _runners.keys():
		if not seen_scenario_ids.has(String(scenario_id)):
			return harness.fail_result("formal pair interaction missing catalog coverage for scenario_id: %s" % String(scenario_id))
	return harness.pass_result()

func run_case(harness, case_spec: Dictionary) -> Dictionary:
	var scenario_id := String(case_spec.get("scenario_id", "")).strip_edges()
	var runner: Callable = _runners.get(scenario_id, Callable())
	if not runner.is_valid():
		return harness.fail_result("formal pair interaction unknown scenario_id: %s" % scenario_id)
	return runner.call(harness, case_spec)

func _is_positive_whole_number(value) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return numeric_value > 0.0 and is_equal_approx(numeric_value, floor(numeric_value))
