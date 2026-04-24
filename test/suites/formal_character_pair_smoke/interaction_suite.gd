extends "res://test/support/gdunit_suite_bridge.gd"

const SharedScript := preload("res://test/suites/formal_character_pair_smoke/shared.gd")
const InteractionSupportScript := preload("res://test/suites/formal_character_pair_smoke/interaction_support.gd")

var _shared = SharedScript.new()
var _interaction_support = InteractionSupportScript.new()

func test_formal_pair_interaction_case_catalog_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_catalog_contract(_harness, sample_factory, interaction_cases))

func test_formal_pair_interaction_cases_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_interaction_cases(_harness, interaction_cases))

func _test_catalog_contract(harness, sample_factory, interaction_cases: Array) -> Dictionary:
	var matrix_result: Dictionary = _shared.validate_unordered_interaction_matrix(harness, sample_factory, interaction_cases)
	if not bool(matrix_result.get("ok", false)):
		return matrix_result
	return _interaction_support.validate_case_catalog(harness, interaction_cases)

func _test_interaction_cases(harness, interaction_cases: Array) -> Dictionary:
	if interaction_cases.is_empty():
		return harness.fail_result("formal pair interaction should derive at least one case")
	for raw_case_spec in interaction_cases:
		if not (raw_case_spec is Dictionary):
			return harness.fail_result("formal pair interaction case must be Dictionary")
		var result: Dictionary = _interaction_support.run_case(harness, raw_case_spec)
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()
