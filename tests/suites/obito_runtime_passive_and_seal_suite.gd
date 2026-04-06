extends RefCounted
class_name ObitoRuntimePassiveAndSealSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")
const ObitoRuntimeContractSupportScript := preload("res://tests/support/obito_runtime_contract_support.gd")

var _support = ObitoTestSupportScript.new()
var _contract_support = ObitoRuntimeContractSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("obito_passive_missing_hp_heal_contract", failures, Callable(self, "_test_obito_passive_missing_hp_heal_contract").bind(harness))
    runner.run_test("obito_qiudao_jiaotu_heal_block_contract", failures, Callable(self, "_test_obito_qiudao_jiaotu_heal_block_contract").bind(harness))
    runner.run_test("obito_qiudao_jiaotu_expire_sync_contract", failures, Callable(self, "_test_obito_qiudao_jiaotu_expire_sync_contract").bind(harness))
    runner.run_test("obito_qiudao_jiaotu_switch_persist_contract", failures, Callable(self, "_test_obito_qiudao_jiaotu_switch_persist_contract").bind(harness))

func _test_obito_passive_missing_hp_heal_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), 1510)
    var obito = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if obito == null or target == null:
        return harness.fail_result("missing active units for obito passive contract")
    obito.current_hp = obito.max_hp - 1

    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_wait_command(core, 1, "P1", "P1-A"),
        _support.build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    if int(obito.current_hp) != int(obito.max_hp):
        return harness.fail_result("obito passive should heal 1 when missing_hp is 1 under current shared contract")

    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_wait_command(core, 2, "P1", "P1-A"),
        _support.build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    if _support.collect_target_heal_events(core.service("battle_logger").event_log, obito.unit_instance_id).size() != 0:
        return harness.fail_result("obito passive should not write heal event while already at full hp")
    return harness.pass_result()

func _test_obito_qiudao_jiaotu_heal_block_contract(harness) -> Dictionary:
    return _contract_support.run_qiudao_jiaotu_heal_block_contract(harness)

func _test_obito_qiudao_jiaotu_switch_persist_contract(harness) -> Dictionary:
    return _contract_support.run_qiudao_jiaotu_switch_persist_contract(harness)

func _test_obito_qiudao_jiaotu_expire_sync_contract(harness) -> Dictionary:
    return _contract_support.run_qiudao_jiaotu_expire_sync_contract(harness)
