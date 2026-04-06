extends "res://tests/suites/extension_validation_contract/base.gd"
const BaseSuiteScript := preload("res://tests/suites/extension_validation_contract/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("formal_kashimo_validator_bad_case_contract", failures, Callable(self, "_test_formal_kashimo_validator_bad_case_contract").bind(harness))
	runner.run_test("formal_kashimo_validator_kyokyo_bad_case_contract", failures, Callable(self, "_test_formal_kashimo_validator_kyokyo_bad_case_contract").bind(harness))
	runner.run_test("formal_kashimo_validator_charge_mark_bad_case_contract", failures, Callable(self, "_test_formal_kashimo_validator_charge_mark_bad_case_contract").bind(harness))
	runner.run_test("formal_kashimo_validator_thunder_resist_surface_bad_case_contract", failures, Callable(self, "_test_formal_kashimo_validator_thunder_resist_surface_bad_case_contract").bind(harness))

func _test_formal_kashimo_validator_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var kashimo_charge = content_index.skills.get("kashimo_charge", null)
	if kashimo_charge == null:
		return harness.fail_result("missing kashimo_charge")
	kashimo_charge.mp_cost = 9
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[kashimo].charge mp_cost mismatch: expected 8 got 9"):
		return harness.fail_result("kashimo formal validator should fail-fast when charge mp_cost drifts")
	return harness.pass_result()

func _test_formal_kashimo_validator_kyokyo_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var kyokyo = content_index.skills.get("kashimo_kyokyo_katsura", null)
	if kyokyo == null:
		return harness.fail_result("missing kashimo_kyokyo_katsura")
	kyokyo.priority = 1
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[kashimo].kyokyo priority mismatch: expected 2 got 1"):
		return harness.fail_result("kashimo formal validator should fail-fast when kyokyo priority drifts")
	return harness.pass_result()

func _test_formal_kashimo_validator_charge_mark_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var negative_mark = content_index.effects.get("kashimo_negative_charge_mark", null)
	if negative_mark == null:
		return harness.fail_result("missing kashimo_negative_charge_mark")
	negative_mark.max_stacks = 2
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[kashimo].negative_charge_mark max_stacks mismatch: expected 3 got 2"):
		return harness.fail_result("kashimo formal validator should fail-fast when negative charge stack cap drifts")
	return harness.pass_result()

func _test_formal_kashimo_validator_thunder_resist_surface_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var thunder_resist = content_index.effects.get("kashimo_thunder_resist", null)
	if thunder_resist == null:
		return harness.fail_result("missing kashimo_thunder_resist")
	thunder_resist.scope = "target"
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[kashimo].thunder_resist scope mismatch: expected self got target"):
		return harness.fail_result("kashimo formal validator should fail-fast when thunder_resist surface drifts")
	return harness.pass_result()
