extends SceneTree

const BattleCoreTestHarnessScript := preload("res://tests/support/battle_core_test_harness.gd")
const ReplayTurnSuiteScript := preload("res://tests/suites/replay_turn_suite.gd")
const LifecycleCoreSuiteScript := preload("res://tests/suites/lifecycle_core_suite.gd")
const ForcedReplaceSuiteScript := preload("res://tests/suites/forced_replace_suite.gd")
const ActionGuardSuiteScript := preload("res://tests/suites/action_guard_suite.gd")
const RuleModSuiteScript := preload("res://tests/suites/rule_mod_suite.gd")
const BattleResultServiceSuiteScript := preload("res://tests/suites/battle_result_service_suite.gd")
const SukunaSuiteScript := preload("res://tests/suites/sukuna_suite.gd")
const ContentLoggingSuiteScript := preload("res://tests/suites/content_logging_suite.gd")
const SetupLoadoutSuiteScript := preload("res://tests/suites/setup_loadout_suite.gd")
const PublicIdAllocatorSuiteScript := preload("res://tests/suites/public_id_allocator_suite.gd")
const ManagerContractSuiteScript := preload("res://tests/suites/manager_contract_suite.gd")
const CombatTypeSuiteScript := preload("res://tests/suites/combat_type_suite.gd")
const DamagePayloadContractSuiteScript := preload("res://tests/suites/damage_payload_contract_suite.gd")

var _harness

func _init() -> void:
    var failures: Array[String] = []
    _harness = BattleCoreTestHarnessScript.new()
    var suites: Array = [
        ReplayTurnSuiteScript.new(),
        LifecycleCoreSuiteScript.new(),
        ForcedReplaceSuiteScript.new(),
        ActionGuardSuiteScript.new(),
        RuleModSuiteScript.new(),
        BattleResultServiceSuiteScript.new(),
        SukunaSuiteScript.new(),
        ContentLoggingSuiteScript.new(),
        SetupLoadoutSuiteScript.new(),
        PublicIdAllocatorSuiteScript.new(),
        ManagerContractSuiteScript.new(),
        CombatTypeSuiteScript.new(),
        DamagePayloadContractSuiteScript.new(),
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
