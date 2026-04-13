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

func test_formal_pair_gojo_vs_sukuna_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_gojo_vs_sukuna_manager_smoke_contract"))

func test_formal_pair_gojo_vs_kashimo_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_gojo_vs_kashimo_manager_smoke_contract"))

func test_formal_pair_gojo_vs_obito_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_gojo_vs_obito_manager_smoke_contract"))

func test_formal_pair_sukuna_vs_gojo_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_sukuna_vs_gojo_manager_smoke_contract"))

func test_formal_pair_sukuna_vs_kashimo_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_sukuna_vs_kashimo_manager_smoke_contract"))

func test_formal_pair_sukuna_vs_obito_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_sukuna_vs_obito_manager_smoke_contract"))

func test_formal_pair_kashimo_vs_gojo_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_kashimo_vs_gojo_manager_smoke_contract"))

func test_formal_pair_kashimo_vs_sukuna_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_kashimo_vs_sukuna_manager_smoke_contract"))

func test_formal_pair_kashimo_vs_obito_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_kashimo_vs_obito_manager_smoke_contract"))

func test_formal_pair_obito_vs_gojo_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_obito_vs_gojo_manager_smoke_contract"))

func test_formal_pair_obito_vs_sukuna_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_obito_vs_sukuna_manager_smoke_contract"))

func test_formal_pair_obito_vs_kashimo_manager_smoke_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var surface_cases: Array = _harness.build_formal_pair_surface_cases(sample_factory)
	_assert_legacy_result(_test_named_surface_case(_harness, sample_factory, surface_cases, "formal_pair_obito_vs_kashimo_manager_smoke_contract"))

func _test_directed_pair_matrix_contract(harness, sample_factory, surface_cases: Array) -> Dictionary:
	return _shared.validate_directed_surface_matrix(harness, sample_factory, surface_cases)

func _test_named_surface_case(harness, sample_factory, surface_cases: Array, test_name: String) -> Dictionary:
	var case_spec := _shared.find_case_by_test_name(surface_cases, test_name)
	if case_spec.is_empty():
		return harness.fail_result("formal pair smoke missing case_spec for %s" % test_name)
	return _shared.run_surface_case(harness, sample_factory, case_spec)
