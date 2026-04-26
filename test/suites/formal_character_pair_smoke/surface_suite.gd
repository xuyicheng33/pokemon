extends "res://tests/support/gdunit_suite_bridge.gd"

const SharedScript := preload("res://test/suites/formal_character_pair_smoke/shared.gd")

var _shared = SharedScript.new()

func test_formal_pair_smoke_matrix_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	var __legacy_result = _shared.validate_directed_surface_matrix(_harness, sample_factory, surface_cases)
	if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
		fail(str(__legacy_result.get("error", "unknown error")))

func test_formal_pair_surface_cases_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	if surface_cases.is_empty():
		fail("formal pair smoke should derive at least one surface case")
		return
	for raw_case_spec in surface_cases:
		if not (raw_case_spec is Dictionary):
			fail("formal pair smoke case must be Dictionary")
			return
		var case_spec: Dictionary = raw_case_spec
		var result: Dictionary = _shared.run_surface_case(_harness, sample_factory, case_spec)
		if not bool(result.get("ok", false)):
			var __legacy_result = result
			if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
				fail(str(__legacy_result.get("error", "unknown error")))
			return

