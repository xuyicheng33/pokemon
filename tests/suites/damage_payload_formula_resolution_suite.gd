extends RefCounted
class_name DamagePayloadFormulaResolutionSuite

const DamagePayloadContractTestHelperScript := preload("res://tests/support/damage_payload_contract_test_helper.gd")

var _helper = DamagePayloadContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("damage_payload_formula_kind_resolution", failures, Callable(self, "_test_formula_damage_kind_resolution").bind(harness))
func _test_formula_damage_kind_resolution(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var inherited_result = _run_formula_skill_inherited_kind_case(core, sample_factory)
    if inherited_result.has("error"):
        return harness.fail_result(str(inherited_result["error"]))
    if int(inherited_result["damage"]) != int(inherited_result["expected_damage"]):
        return harness.fail_result("skill-chain formula damage should inherit skill damage_kind and stat stages")
    if not is_equal_approx(float(inherited_result["type_effectiveness"]), 2.0):
        return harness.fail_result("skill-chain formula damage should keep inherited combat_type effectiveness")

    var non_skill_result = _run_non_skill_formula_damage_kind_case(core, sample_factory)
    if non_skill_result.has("error"):
        return harness.fail_result(str(non_skill_result["error"]))
    if int(non_skill_result["damage"]) != int(non_skill_result["expected_damage"]):
        return harness.fail_result("non-skill formula damage should use payload damage_kind and stat stages")
    if not is_equal_approx(float(non_skill_result["type_effectiveness"]), 1.0):
        return harness.fail_result("non-skill formula damage should stay neutral")

    return harness.pass_result()

func _run_formula_skill_inherited_kind_case(core, sample_factory) -> Dictionary:
    return _helper._run_formula_skill_inherited_kind_case(core, sample_factory)

func _run_non_skill_formula_damage_kind_case(core, sample_factory) -> Dictionary:
    return _helper._run_non_skill_formula_damage_kind_case(core, sample_factory)
