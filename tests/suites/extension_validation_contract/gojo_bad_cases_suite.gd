extends "res://tests/suites/extension_validation_contract/base.gd"
const BaseSuiteScript := preload("res://tests/suites/extension_validation_contract/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("formal_gojo_validator_bad_case_contract", failures, Callable(self, "_test_formal_gojo_validator_bad_case_contract").bind(harness))
	runner.run_test("formal_gojo_validator_reverse_bad_case_contract", failures, Callable(self, "_test_formal_gojo_validator_reverse_bad_case_contract").bind(harness))
	runner.run_test("formal_gojo_validator_murasaki_cleanup_bad_case_contract", failures, Callable(self, "_test_formal_gojo_validator_murasaki_cleanup_bad_case_contract").bind(harness))
	runner.run_test("formal_gojo_validator_action_lock_surface_bad_case_contract", failures, Callable(self, "_test_formal_gojo_validator_action_lock_surface_bad_case_contract").bind(harness))
	runner.run_test("formal_gojo_validator_action_lock_stacking_bad_case_contract", failures, Callable(self, "_test_formal_gojo_validator_action_lock_stacking_bad_case_contract").bind(harness))

func _test_formal_gojo_validator_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var gojo_ao = content_index.skills.get("gojo_ao", null)
	if gojo_ao == null:
		return harness.fail_result("missing gojo_ao")
	gojo_ao.power = 45
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[gojo_satoru].ao power mismatch: expected 44 got 45"):
		return harness.fail_result("gojo formal validator should fail-fast when ao power drifts")
	return harness.pass_result()

func _test_formal_gojo_validator_reverse_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var gojo_reverse_ritual = content_index.skills.get("gojo_reverse_ritual", null)
	if gojo_reverse_ritual == null:
		return harness.fail_result("missing gojo_reverse_ritual")
	gojo_reverse_ritual.mp_cost = 15
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[gojo_satoru].reverse_ritual mp_cost mismatch: expected 14 got 15"):
		return harness.fail_result("gojo formal validator should fail-fast when reverse_ritual mp_cost drifts")
	return harness.pass_result()

func _test_formal_gojo_validator_murasaki_cleanup_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var murasaki_burst = content_index.effects.get("gojo_murasaki_conditional_burst", null)
	if murasaki_burst == null or murasaki_burst.payloads.size() < 3:
		return harness.fail_result("missing gojo_murasaki_conditional_burst cleanup payloads")
	murasaki_burst.payloads[1].effect_definition_id = "gojo_aka_mark"
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, 'formal[gojo_satoru].murasaki_burst payload[1].effect_definition_id mismatch: expected "gojo_ao_mark" got "gojo_aka_mark"'):
		return harness.fail_result("gojo formal validator should fail-fast when murasaki cleanup payload drifts")
	return harness.pass_result()

func _test_formal_gojo_validator_action_lock_surface_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var action_lock = content_index.effects.get("gojo_domain_action_lock", null)
	if action_lock == null:
		return harness.fail_result("missing gojo_domain_action_lock")
	action_lock.scope = "self"
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "formal[gojo_satoru].domain_buff_contract action_lock scope mismatch: expected target got self"):
		return harness.fail_result("gojo formal validator should fail-fast when action_lock surface drifts")
	return harness.pass_result()

func _test_formal_gojo_validator_action_lock_stacking_bad_case_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var action_lock = content_index.effects.get("gojo_domain_action_lock", null)
	if action_lock == null or action_lock.payloads.is_empty():
		return harness.fail_result("missing gojo_domain_action_lock payload")
	action_lock.payloads[0].stacking = "refresh"
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, 'formal[gojo_satoru].domain_buff_contract action_lock.stacking mismatch: expected "replace" got "refresh"'):
		return harness.fail_result("gojo formal validator should fail-fast when action_lock stacking drifts")
	return harness.pass_result()
