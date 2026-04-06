extends RefCounted
class_name FormalCharacterPairSmokeInteractionSuite

const SharedScript := preload("res://tests/suites/formal_character_pair_smoke/shared.gd")
const InteractionSupportScript := preload("res://tests/suites/formal_character_pair_smoke/interaction_support.gd")

var _shared = SharedScript.new()
var _interaction_support = InteractionSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		runner.run_test("formal_pair_interaction_sample_factory_contract", failures, Callable(self, "_test_sample_factory_contract").bind(harness))
		return
	var interaction_cases: Array = harness.build_formal_pair_interaction_cases(sample_factory)
	runner.run_test(
		"formal_pair_interaction_case_catalog_contract",
		failures,
		Callable(self, "_test_catalog_contract").bind(harness, sample_factory, interaction_cases)
	)
	for raw_case_spec in interaction_cases:
		if not (raw_case_spec is Dictionary):
			continue
		var case_spec: Dictionary = raw_case_spec
		var test_name := String(case_spec.get("test_name", "")).strip_edges()
		if test_name.is_empty():
			continue
		runner.run_test(test_name, failures, Callable(self, "_test_named_interaction_case").bind(harness, interaction_cases, test_name))

func _test_sample_factory_contract(harness) -> Dictionary:
	return harness.fail_result("SampleBattleFactory init failed")

func _test_catalog_contract(harness, sample_factory, interaction_cases: Array) -> Dictionary:
	var matrix_result: Dictionary = _shared.validate_unordered_interaction_matrix(harness, sample_factory, interaction_cases)
	if not bool(matrix_result.get("ok", false)):
		return matrix_result
	return _interaction_support.validate_case_catalog(harness, interaction_cases)

func _test_named_interaction_case(harness, interaction_cases: Array, test_name: String) -> Dictionary:
	var case_spec := _shared.find_case_by_test_name(interaction_cases, test_name)
	if case_spec.is_empty():
		return harness.fail_result("formal pair interaction missing case_spec for %s" % test_name)
	return _interaction_support.run_case(harness, case_spec)
