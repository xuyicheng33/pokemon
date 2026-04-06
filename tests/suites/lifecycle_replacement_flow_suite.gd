extends RefCounted
class_name LifecycleReplacementFlowSuite

const FaintReplaceSuiteScript := preload("res://tests/suites/lifecycle_replacement_flow/faint_replace_suite.gd")
const ManualSwitchSuiteScript := preload("res://tests/suites/lifecycle_replacement_flow/manual_switch_suite.gd")
const ReplacementContractSuiteScript := preload("res://tests/suites/lifecycle_replacement_flow/replacement_contract_suite.gd")
const SelectorPathsSuiteScript := preload("res://tests/suites/lifecycle_replacement_flow/selector_paths_suite.gd")

var _faint_replace_suite = FaintReplaceSuiteScript.new()
var _manual_switch_suite = ManualSwitchSuiteScript.new()
var _replacement_contract_suite = ReplacementContractSuiteScript.new()
var _selector_paths_suite = SelectorPathsSuiteScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    _faint_replace_suite.register_tests(runner, failures, harness)
    _manual_switch_suite.register_tests(runner, failures, harness)
    _replacement_contract_suite.register_tests(runner, failures, harness)
    _selector_paths_suite.register_tests(runner, failures, harness)
