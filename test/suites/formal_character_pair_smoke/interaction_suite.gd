extends "res://tests/support/gdunit_suite_bridge.gd"

const SharedScript := preload("res://test/suites/formal_character_pair_smoke/shared.gd")
const InteractionSharedScript := preload("res://test/suites/formal_character_pair_smoke/interaction_shared.gd")

var _shared = SharedScript.new()
var _interaction_shared = InteractionSharedScript.new()

func test_formal_pair_interaction_case_catalog_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	var matrix_result: Dictionary = _shared.validate_unordered_interaction_matrix(_harness, sample_factory, interaction_cases)
	if not bool(matrix_result.get("ok", false)):
		var __legacy_result = matrix_result
		if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
			fail(str(__legacy_result.get("error", "unknown error")))
		return
	var __legacy_result = _interaction_shared.validate_case_catalog(_harness, interaction_cases)
	if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
		fail(str(__legacy_result.get("error", "unknown error")))

func test_formal_pair_interaction_cases_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	if interaction_cases.is_empty():
		fail("formal pair interaction should derive at least one case")
		return
	for raw_case_spec in interaction_cases:
		if not (raw_case_spec is Dictionary):
			fail("formal pair interaction case must be Dictionary")
			return
		var result: Dictionary = _interaction_shared.run_case(_harness, raw_case_spec)
		if not bool(result.get("ok", false)):
			var __legacy_result = result
			if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
				fail(str(__legacy_result.get("error", "unknown error")))
			return

