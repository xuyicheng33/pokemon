extends RefCounted
class_name ObitoManagerSmokeSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var _helper = ManagerContractTestHelperScript.new()
var _support = ObitoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("obito_manager_smoke_contract", failures, Callable(self, "_test_obito_manager_smoke_contract").bind(harness))
    runner.run_test("obito_manager_public_contract", failures, Callable(self, "_test_obito_manager_public_contract").bind(harness))

func _test_obito_manager_smoke_contract(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var init_unwrap = _helper.unwrap_ok(manager.create_session({
        "battle_seed": 1550,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": sample_factory.build_obito_vs_sample_setup(),
    }), "create_session")
    if not bool(init_unwrap.get("ok", false)):
        return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
    var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
    var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
    if not bool(legal_actions_unwrap.get("ok", false)):
        return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
    var legal_actions = legal_actions_unwrap.get("data", null)
    if String(legal_actions.actor_public_id) != "P1-A":
        return harness.fail_result("obito manager smoke should expose actor_public_id=P1-A")
    if not legal_actions.legal_skill_ids.has("obito_qiudao_jiaotu"):
        return harness.fail_result("obito manager smoke legal actions should include obito_qiudao_jiaotu")
    if not legal_actions.legal_ultimate_ids.is_empty():
        return harness.fail_result("obito manager smoke turn 1 should not expose ultimate before points are charged")
    var obito_command = _helper.unwrap_ok(manager.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": "P1",
        "actor_public_id": "P1-A",
        "skill_id": "obito_qiudao_jiaotu",
    }), "build_command(obito_qiudao_jiaotu)")
    if not bool(obito_command.get("ok", false)):
        return harness.fail_result(str(obito_command.get("error", "manager build_command failed")))
    var wait_command = _helper.unwrap_ok(manager.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.WAIT,
        "command_source": "manual",
        "side_id": "P2",
        "actor_public_id": "P2-A",
    }), "build_command(wait)")
    if not bool(wait_command.get("ok", false)):
        return harness.fail_result(str(wait_command.get("error", "manager build_command failed")))
    var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
        obito_command.get("data", null),
        wait_command.get("data", null),
    ]), "run_turn")
    if not bool(run_turn_unwrap.get("ok", false)):
        return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
    var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
    if not bool(public_snapshot_unwrap.get("ok", false)):
        return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
    var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
    var shape_error := _helper.validate_snapshot_shape(public_snapshot)
    if not shape_error.is_empty():
        return harness.fail_result("obito manager smoke public snapshot malformed: %s" % shape_error)
    var target_snapshot := _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
    if target_snapshot.is_empty():
        return harness.fail_result("obito manager smoke missing target public snapshot")
    if not _helper.unit_snapshot_has_effect(target_snapshot, "obito_qiudao_jiaotu_heal_block_mark"):
        return harness.fail_result("obito manager smoke should expose heal block mark on P2-A")
    var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
    if not bool(event_log_unwrap.get("ok", false)):
        return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
    var events: Array = event_log_unwrap.get("data", {}).get("events", [])
    if _helper.contains_runtime_id_leak(events):
        return harness.fail_result("obito manager smoke event log must stay public-safe")
    if not _helper.event_log_has_public_action_cast(events, "P1-A", "obito_juubi_jinchuriki"):
        return harness.fail_result("obito manager smoke event log should expose obito public action cast")
    var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
    if not bool(close_unwrap.get("ok", false)):
        return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
    return harness.pass_result()

func _test_obito_manager_public_contract(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var init_unwrap = _helper.unwrap_ok(manager.create_session({
        "battle_seed": 1551,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": _support.build_obito_mirror_setup(sample_factory),
    }), "create_session")
    if not bool(init_unwrap.get("ok", false)):
        return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
    var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
    var charge_skill_ids := {
        1: "obito_qiudao_jiaotu",
        2: "obito_qiudao_jiaotu",
        3: "obito_qiudao_jiaotu",
    }
    for turn_index in [1, 2, 3]:
        var skill_command = _helper.unwrap_ok(manager.build_command({
            "turn_index": turn_index,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": String(charge_skill_ids.get(turn_index, "")),
        }), "build_command(charge_obito_%d)" % turn_index)
        if not bool(skill_command.get("ok", false)):
            return harness.fail_result(str(skill_command.get("error", "manager build_command failed")))
        var wait_command = _helper.unwrap_ok(manager.build_command({
            "turn_index": turn_index,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "obito_yinyang_dun",
        }), "build_command(defend_obito_%d)" % turn_index)
        if not bool(wait_command.get("ok", false)):
            return harness.fail_result(str(wait_command.get("error", "manager build_command failed")))
        var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
            skill_command.get("data", null),
            wait_command.get("data", null),
        ]), "run_turn charge_obito")
        if not bool(run_turn_unwrap.get("ok", false)):
            return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
    var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
    if not bool(legal_actions_unwrap.get("ok", false)):
        return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
    var legal_actions = legal_actions_unwrap.get("data", null)
    if not legal_actions.legal_ultimate_ids.has("obito_shiwei_weishouyu"):
        return harness.fail_result("obito manager public path should expose ultimate after 3 regular casts")
    var pre_ultimate_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(pre_ultimate)")
    if not bool(pre_ultimate_log_unwrap.get("ok", false)):
        return harness.fail_result(str(pre_ultimate_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
    var pre_ultimate_total_size := int(pre_ultimate_log_unwrap.get("data", {}).get("total_size", 0))
    var ultimate_command = _helper.unwrap_ok(manager.build_command({
        "turn_index": 4,
        "command_type": CommandTypesScript.ULTIMATE,
        "command_source": "manual",
        "side_id": "P1",
        "actor_public_id": "P1-A",
        "skill_id": "obito_shiwei_weishouyu",
    }), "build_command(obito_shiwei_weishouyu)")
    if not bool(ultimate_command.get("ok", false)):
        return harness.fail_result(str(ultimate_command.get("error", "manager build_command failed")))
    var wait_turn_4 = _helper.unwrap_ok(manager.build_command({
        "turn_index": 4,
        "command_type": CommandTypesScript.WAIT,
        "command_source": "manual",
        "side_id": "P2",
        "actor_public_id": "P2-A",
    }), "build_command(wait turn4)")
    if not bool(wait_turn_4.get("ok", false)):
        return harness.fail_result(str(wait_turn_4.get("error", "manager build_command failed")))
    var ultimate_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
        ultimate_command.get("data", null),
        wait_turn_4.get("data", null),
    ]), "run_turn obito ultimate")
    if not bool(ultimate_turn_unwrap.get("ok", false)):
        return harness.fail_result(str(ultimate_turn_unwrap.get("error", "manager run_turn failed")))
    var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
    if not bool(public_snapshot_unwrap.get("ok", false)):
        return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
    var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
    if _helper.validate_snapshot_shape(public_snapshot) != "":
        return harness.fail_result("obito manager public path should keep snapshot shape stable")
    var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id, pre_ultimate_total_size), "get_event_log_snapshot")
    if not bool(event_log_unwrap.get("ok", false)):
        return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
    var events: Array = event_log_unwrap.get("data", {}).get("events", [])
    if _helper.contains_runtime_id_leak(events):
        return harness.fail_result("obito manager public path event log must stay public-safe")
    var damage_events: Array = []
    for event_snapshot in events:
        if String(event_snapshot.get("event_type", "")) != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(event_snapshot.get("actor_public_id", "")) != "P1-A":
            continue
        damage_events.append(event_snapshot)
    if damage_events.size() != 10:
        return harness.fail_result("obito manager public path should expose 10 public damage events for ultimate, got %d" % damage_events.size())
    var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
    if not bool(close_unwrap.get("ok", false)):
        return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
    return harness.pass_result()
