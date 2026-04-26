extends "res://tests/support/gdunit_suite_bridge.gd"

const DamagePayloadContractTestHelperScript := preload("res://tests/support/damage_payload_contract_test_helper.gd")

var _helper = DamagePayloadContractTestHelperScript.new()


func test_damage_payload_formula_kind_resolution() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return

	var inherited_result = _run_formula_skill_inherited_kind_case(core, sample_factory)
	if inherited_result.has("error"):
		fail(str(inherited_result["error"]))
		return
	if int(inherited_result["damage"]) != int(inherited_result["expected_damage"]):
		fail("skill-chain formula damage should inherit skill damage_kind and stat stages")
		return
	if not is_equal_approx(float(inherited_result["type_effectiveness"]), 2.0):
		fail("skill-chain formula damage should keep inherited combat_type effectiveness")
		return

	var non_skill_result = _run_non_skill_formula_damage_kind_case(core, sample_factory)
	if non_skill_result.has("error"):
		fail(str(non_skill_result["error"]))
		return
	if int(non_skill_result["damage"]) != int(non_skill_result["expected_damage"]):
		fail("non-skill formula damage should use payload damage_kind and stat stages")
		return
	if not is_equal_approx(float(non_skill_result["type_effectiveness"]), 1.0):
		fail("non-skill formula damage should stay neutral")
		return

func _run_formula_skill_inherited_kind_case(core, sample_factory) -> Dictionary:
	return _helper.run_formula_skill_inherited_kind_case(core, sample_factory)

func _run_non_skill_formula_damage_kind_case(core, sample_factory) -> Dictionary:
	return _helper.run_non_skill_formula_damage_kind_case(core, sample_factory)
