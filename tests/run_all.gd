extends SceneTree

const BattleCoreTestHarnessScript := preload("res://tests/support/battle_core_test_harness.gd")
const ReplayTurnSuiteScript := preload("res://tests/suites/replay_turn_suite.gd")
const LifecycleReplaceSuiteScript := preload("res://tests/suites/lifecycle_replace_suite.gd")
const ActionGuardSuiteScript := preload("res://tests/suites/action_guard_suite.gd")
const RuleModSuiteScript := preload("res://tests/suites/rule_mod_suite.gd")
const ContentLoggingSuiteScript := preload("res://tests/suites/content_logging_suite.gd")
const FacadeContractSuiteScript := preload("res://tests/suites/facade_contract_suite.gd")

var _harness

func _init() -> void:
    var failures: Array[String] = []
    _harness = BattleCoreTestHarnessScript.new()
    var suites: Array = [
        ReplayTurnSuiteScript.new(),
        LifecycleReplaceSuiteScript.new(),
        ActionGuardSuiteScript.new(),
        RuleModSuiteScript.new(),
        ContentLoggingSuiteScript.new(),
        FacadeContractSuiteScript.new(),
    ]
    for suite in suites:
        suite.register_tests(self, failures, _harness)
    _harness.dispose_core_pool()
    if failures.is_empty():
        print("ALL TESTS PASSED")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func run_test(test_name: String, failures: Array[String], test_callable: Callable) -> void:
    var result = test_callable.call()
    if typeof(result) != TYPE_DICTIONARY or not result.has("ok"):
        failures.append("%s: malformed test result" % test_name)
        return
    if bool(result["ok"]):
        print("PASS %s" % test_name)
        return
    failures.append("%s: %s" % [test_name, str(result.get("error", "unknown error"))])
