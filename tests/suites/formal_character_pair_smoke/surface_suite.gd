extends RefCounted
class_name FormalCharacterPairSmokeSurfaceSuite

const SharedScript := preload("res://tests/suites/formal_character_pair_smoke/shared.gd")

var _shared = SharedScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		runner.run_test("formal_pair_smoke_sample_factory_contract", failures, Callable(self, "_test_sample_factory_contract").bind(harness))
		return
	var surface_cases: Array = harness.build_formal_pair_surface_cases(sample_factory)
	runner.run_test(
		"formal_pair_smoke_matrix_contract",
		failures,
		Callable(self, "_test_directed_pair_matrix_contract").bind(harness, sample_factory, surface_cases)
	)
	for raw_case_spec in surface_cases:
		if not (raw_case_spec is Dictionary):
			continue
		var case_spec: Dictionary = raw_case_spec
		var test_name := String(case_spec.get("test_name", "")).strip_edges()
		if test_name.is_empty():
			continue
		runner.run_test(test_name, failures, Callable(self, "_test_named_surface_case").bind(harness, sample_factory, surface_cases, test_name))

func _test_sample_factory_contract(harness) -> Dictionary:
	return harness.fail_result("SampleBattleFactory init failed")

func _test_directed_pair_matrix_contract(harness, sample_factory, surface_cases: Array) -> Dictionary:
	return _shared.validate_directed_surface_matrix(harness, sample_factory, surface_cases)

func _test_named_surface_case(harness, sample_factory, surface_cases: Array, test_name: String) -> Dictionary:
	var case_spec := _shared.find_case_by_test_name(surface_cases, test_name)
	if case_spec.is_empty():
		return harness.fail_result("formal pair smoke missing case_spec for %s" % test_name)
	return _shared.run_surface_case(harness, sample_factory, case_spec)
