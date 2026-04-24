extends "res://test/support/gdunit_suite_bridge.gd"

const SharedScript := preload("res://test/suites/formal_character_pair_smoke/shared.gd")

var _shared = SharedScript.new()

func test_formal_pair_smoke_matrix_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_directed_pair_matrix_contract(_harness, sample_factory, surface_cases))

func test_formal_pair_surface_cases_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_surface_cases(_harness, sample_factory, surface_cases))

func _test_directed_pair_matrix_contract(harness, sample_factory, surface_cases: Array) -> Dictionary:
	return _shared.validate_directed_surface_matrix(harness, sample_factory, surface_cases)

func _test_surface_cases(harness, sample_factory, surface_cases: Array) -> Dictionary:
	if surface_cases.is_empty():
		return harness.fail_result("formal pair smoke should derive at least one surface case")
	for raw_case_spec in surface_cases:
		if not (raw_case_spec is Dictionary):
			return harness.fail_result("formal pair smoke case must be Dictionary")
		var case_spec: Dictionary = raw_case_spec
		var result: Dictionary = _shared.run_surface_case(harness, sample_factory, case_spec)
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()
