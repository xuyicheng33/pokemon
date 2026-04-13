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

func test_formal_pair_sukuna_vs_gojo_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_sukuna_vs_gojo_interaction_contract"))

func test_formal_pair_gojo_vs_sukuna_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_gojo_vs_sukuna_interaction_contract"))

func test_formal_pair_kashimo_vs_gojo_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_kashimo_vs_gojo_interaction_contract"))

func test_formal_pair_gojo_vs_kashimo_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_gojo_vs_kashimo_interaction_contract"))

func test_formal_pair_kashimo_vs_sukuna_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_kashimo_vs_sukuna_interaction_contract"))

func test_formal_pair_sukuna_vs_kashimo_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_sukuna_vs_kashimo_interaction_contract"))

func test_formal_pair_obito_vs_gojo_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_obito_vs_gojo_interaction_contract"))

func test_formal_pair_gojo_vs_obito_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_gojo_vs_obito_interaction_contract"))

func test_formal_pair_obito_vs_sukuna_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_obito_vs_sukuna_interaction_contract"))

func test_formal_pair_sukuna_vs_obito_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_sukuna_vs_obito_interaction_contract"))

func test_formal_pair_obito_vs_kashimo_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_obito_vs_kashimo_interaction_contract"))

func test_formal_pair_kashimo_vs_obito_interaction_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var interaction_cases: Array = _harness.build_formal_pair_interaction_cases(sample_factory)
	_assert_legacy_result(_test_named_interaction_case(_harness, interaction_cases, "formal_pair_kashimo_vs_obito_interaction_contract"))

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
