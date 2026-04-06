extends "res://tests/suites/extension_validation_contract/base.gd"
const BaseSuiteScript := preload("res://tests/suites/extension_validation_contract/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("formal_sukuna_validator_bad_case_contract", failures, Callable(self, "_test_formal_sukuna_validator_bad_case_contract").bind(harness))
	runner.run_test("formal_sukuna_validator_reverse_bad_case_contract", failures, Callable(self, "_test_formal_sukuna_validator_reverse_bad_case_contract").bind(harness))
	runner.run_test("formal_sukuna_validator_regen_surface_bad_case_contract", failures, Callable(self, "_test_formal_sukuna_validator_regen_surface_bad_case_contract").bind(harness))

func _test_formal_sukuna_validator_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var sukuna_kai = content_index.skills.get("sukuna_kai", null)
	if sukuna_kai == null:
		return harness.fail_result("missing sukuna_kai")
	sukuna_kai.priority = 0
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[sukuna].kai priority mismatch: expected 1 got 0"):
		return harness.fail_result("sukuna formal validator should fail-fast when kai priority drifts")
	return harness.pass_result()

func _test_formal_sukuna_validator_reverse_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var sukuna_reverse_ritual = content_index.skills.get("sukuna_reverse_ritual", null)
	if sukuna_reverse_ritual == null:
		return harness.fail_result("missing sukuna_reverse_ritual")
	sukuna_reverse_ritual.mp_cost = 15
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[sukuna].reverse_ritual mp_cost mismatch: expected 14 got 15"):
		return harness.fail_result("sukuna formal validator should fail-fast when reverse_ritual mp_cost drifts")
	return harness.pass_result()

func _test_formal_sukuna_validator_regen_surface_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var regen_effect = content_index.effects.get("sukuna_refresh_love_regen", null)
	if regen_effect == null:
		return harness.fail_result("missing sukuna_refresh_love_regen")
	regen_effect.stacking = "refresh"
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[sukuna].teach_love effect stacking mismatch: expected none got refresh"):
		return harness.fail_result("sukuna formal validator should fail-fast when regen surface drifts")
	return harness.pass_result()
