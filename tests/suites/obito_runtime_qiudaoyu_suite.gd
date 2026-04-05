extends RefCounted
class_name ObitoRuntimeQiudaoYuSuite

const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")

var _support = ObitoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("obito_qiudaoyu_power_bonus_contract", failures, Callable(self, "_test_obito_qiudaoyu_power_bonus_contract").bind(harness))
    runner.run_test("obito_qiudaoyu_execute_contract", failures, Callable(self, "_test_obito_qiudaoyu_execute_contract").bind(harness))
    runner.run_test("obito_qiudaoyu_hit_and_miss_clear_contract", failures, Callable(self, "_test_obito_qiudaoyu_hit_and_miss_clear_contract").bind(harness))

func _test_obito_qiudaoyu_power_bonus_contract(harness) -> Dictionary:
    var baseline = _run_qiudaoyu_damage_case(harness, 0, 1530, false)
    if not bool(baseline.get("ok", false)):
        return harness.fail_result(str(baseline.get("error", "baseline qiudaoyu case failed")))
    var charged = _run_qiudaoyu_damage_case(harness, 3, 1531, false)
    if not bool(charged.get("ok", false)):
        return harness.fail_result(str(charged.get("error", "charged qiudaoyu case failed")))
    if int(charged.get("damage", -1)) <= int(baseline.get("damage", -1)):
        return harness.fail_result("obito_qiudaoyu should deal more damage when yinyang stacks are present")
    if int(charged.get("remaining_stacks", -1)) != 0:
        return harness.fail_result("obito_qiudaoyu should clear all yinyang stacks on hit")
    return harness.pass_result()

func _test_obito_qiudaoyu_execute_contract(harness) -> Dictionary:
    var result = _run_qiudaoyu_execute_case(harness, 1532)
    if not bool(result.get("ok", false)):
        return harness.fail_result(str(result.get("error", "obito qiudaoyu execute case failed")))
    if int(result.get("target_hp", -1)) != 0:
        return harness.fail_result("obito_qiudaoyu should execute target at <= 30% hp with 5 stacks")
    if not bool(result.get("execute_log", false)):
        return harness.fail_result("obito_qiudaoyu execute path should emit [execute] damage log")
    if int(result.get("remaining_stacks", -1)) != 0:
        return harness.fail_result("obito_qiudaoyu execute path should still clear all yinyang stacks")
    return harness.pass_result()

func _test_obito_qiudaoyu_hit_and_miss_clear_contract(harness) -> Dictionary:
    var hit_result = _run_qiudaoyu_damage_case(harness, 2, 1533, false)
    if not bool(hit_result.get("ok", false)):
        return harness.fail_result(str(hit_result.get("error", "obito qiudaoyu hit clear case failed")))
    if int(hit_result.get("remaining_stacks", -1)) != 0:
        return harness.fail_result("obito_qiudaoyu should clear all yinyang stacks on hit")
    var miss_result = _run_qiudaoyu_damage_case(harness, 2, 1534, true)
    if not bool(miss_result.get("ok", false)):
        return harness.fail_result(str(miss_result.get("error", "obito qiudaoyu miss clear case failed")))
    if int(miss_result.get("remaining_stacks", -1)) != 0:
        return harness.fail_result("obito_qiudaoyu should clear all yinyang stacks on miss")
    return harness.pass_result()

func _run_qiudaoyu_damage_case(harness, preseed_stacks: int, seed: int, force_miss: bool) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return {"ok": false, "error": str(core_payload["error"])}
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return {"ok": false, "error": "SampleBattleFactory init failed"}
    var content_index = harness.build_loaded_content_index(sample_factory)
    if force_miss:
        content_index.skills["obito_qiudao_yu"].accuracy = 0
    var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), seed)
    var obito = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if obito == null or target == null:
        return {"ok": false, "error": "missing active units for obito qiudaoyu damage case"}
    var yinyang_definition = content_index.effects.get("obito_yinyang_zhili", null)
    if yinyang_definition == null:
        return {"ok": false, "error": "missing obito_yinyang_zhili definition"}
    for _i in range(preseed_stacks):
        if core.service("effect_instance_service").create_instance(yinyang_definition, obito.unit_instance_id, battle_state, "test_obito_qiudaoyu", 2, obito.base_speed) == null:
            return {"ok": false, "error": "failed to preseed yinyang stack"}
    var before_hp := int(target.current_hp)
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_qiudao_yu"),
        _support.build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    return {
        "ok": true,
        "damage": before_hp - int(target.current_hp),
        "remaining_stacks": _support.count_effect_instances(obito, "obito_yinyang_zhili"),
    }

func _run_qiudaoyu_execute_case(harness, seed: int) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return {"ok": false, "error": str(core_payload["error"])}
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return {"ok": false, "error": "SampleBattleFactory init failed"}
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), seed)
    var obito = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if obito == null or target == null:
        return {"ok": false, "error": "missing active units for obito qiudaoyu execute case"}
    var yinyang_definition = content_index.effects.get("obito_yinyang_zhili", null)
    if yinyang_definition == null:
        return {"ok": false, "error": "missing obito_yinyang_zhili definition"}
    for _i in range(5):
        if core.service("effect_instance_service").create_instance(yinyang_definition, obito.unit_instance_id, battle_state, "test_obito_qiudaoyu_execute", 2, obito.base_speed) == null:
            return {"ok": false, "error": "failed to preseed execute yinyang stack"}
    target.current_hp = int(floor(float(target.max_hp) * 0.3))
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_qiudao_yu"),
        _support.build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var damage_events = _support.collect_actor_damage_events(core.service("battle_logger").event_log, "P1-A")
    var execute_log := false
    for event in damage_events:
        if String(event.payload_summary).find("[execute]") != -1:
            execute_log = true
            break
    return {
        "ok": true,
        "target_hp": int(target.current_hp),
        "remaining_stacks": _support.count_effect_instances(obito, "obito_yinyang_zhili"),
        "execute_log": execute_log,
    }
