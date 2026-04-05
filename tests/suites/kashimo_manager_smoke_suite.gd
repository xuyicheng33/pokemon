extends RefCounted
class_name KashimoManagerSmokeSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _helper = ManagerContractTestHelperScript.new()
var _support = KashimoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("kashimo_manager_smoke_contract", failures, Callable(self, "_test_kashimo_manager_smoke_contract").bind(harness))
    runner.run_test("kashimo_manager_amber_public_contract", failures, Callable(self, "_test_kashimo_manager_amber_public_contract").bind(harness))

func _test_kashimo_manager_smoke_contract(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var init_unwrap = _helper.unwrap_ok(manager.create_session({
        "battle_seed": 1310,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": _support.build_kashimo_setup(sample_factory),
    }), "create_session")
    if not bool(init_unwrap.get("ok", false)):
        return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
    var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
    var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
    if not bool(legal_actions_unwrap.get("ok", false)):
        return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
    var legal_actions = legal_actions_unwrap.get("data", null)
    if String(legal_actions.actor_public_id) != "P1-A":
        return harness.fail_result("kashimo manager smoke should expose actor_public_id=P1-A")
    if not legal_actions.legal_skill_ids.has("kashimo_raiken"):
        return harness.fail_result("kashimo manager smoke legal actions should include kashimo_raiken")
    if not legal_actions.legal_ultimate_ids.is_empty():
        return harness.fail_result("kashimo manager smoke turn 1 should not expose ultimate before points are charged")
    var kashimo_command_unwrap = _helper.unwrap_ok(manager.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": "P1",
        "actor_public_id": "P1-A",
        "skill_id": "kashimo_raiken",
    }), "build_command(kashimo_raiken)")
    if not bool(kashimo_command_unwrap.get("ok", false)):
        return harness.fail_result(str(kashimo_command_unwrap.get("error", "manager build_command failed")))
    var wait_command_unwrap = _helper.unwrap_ok(manager.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.WAIT,
        "command_source": "manual",
        "side_id": "P2",
        "actor_public_id": "P2-A",
    }), "build_command(wait)")
    if not bool(wait_command_unwrap.get("ok", false)):
        return harness.fail_result(str(wait_command_unwrap.get("error", "manager build_command failed")))
    var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
        kashimo_command_unwrap.get("data", null),
        wait_command_unwrap.get("data", null),
    ]), "run_turn")
    if not bool(run_turn_unwrap.get("ok", false)):
        return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
    var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
    if not bool(public_snapshot_unwrap.get("ok", false)):
        return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
    var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
    var shape_error := _helper.validate_snapshot_shape(public_snapshot)
    if not shape_error.is_empty():
        return harness.fail_result("kashimo manager smoke public snapshot malformed: %s" % shape_error)
    var target_snapshot := _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
    if target_snapshot.is_empty():
        return harness.fail_result("kashimo manager smoke missing target public snapshot")
    if not _helper.unit_snapshot_has_effect(target_snapshot, "kashimo_negative_charge_mark"):
        return harness.fail_result("kashimo manager smoke should expose negative charge on P2-A")
    var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
    if not bool(event_log_unwrap.get("ok", false)):
        return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
    var event_log_snapshot: Dictionary = event_log_unwrap.get("data", {})
    var events: Array = event_log_snapshot.get("events", [])
    if events.is_empty():
        return harness.fail_result("kashimo manager smoke event log should not be empty after run_turn")
    if _helper.contains_runtime_id_leak(events):
        return harness.fail_result("kashimo manager smoke event log must stay public-safe")
    if not _helper.event_log_has_public_action_cast(events, "P1-A", "kashimo_hajime"):
        return harness.fail_result("kashimo manager smoke event log should expose kashimo public action cast")
    var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
    if not bool(close_unwrap.get("ok", false)):
        return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
    return harness.pass_result()

func _test_kashimo_manager_amber_public_contract(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var battle_setup = _support.build_kashimo_setup(sample_factory)
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_mossaur", "sample_pyron", "sample_tidekit"])
    battle_setup.sides[1].starting_index = 0
    var init_unwrap = _helper.unwrap_ok(manager.create_session({
        "battle_seed": 1311,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": battle_setup,
    }), "create_session")
    if not bool(init_unwrap.get("ok", false)):
        return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
    var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
    for turn_index in [1, 2, 3]:
        var charge_command = _helper.unwrap_ok(manager.build_command({
            "turn_index": turn_index,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "kashimo_charge",
        }), "build_command(kashimo_charge)")
        if not bool(charge_command.get("ok", false)):
            return harness.fail_result(str(charge_command.get("error", "manager build_command failed")))
        var wait_command = _helper.unwrap_ok(manager.build_command({
            "turn_index": turn_index,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }), "build_command(wait)")
        if not bool(wait_command.get("ok", false)):
            return harness.fail_result(str(wait_command.get("error", "manager build_command failed")))
        var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
            charge_command.get("data", null),
            wait_command.get("data", null),
        ]), "run_turn charge_kashimo")
        if not bool(run_turn_unwrap.get("ok", false)):
            return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
    var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
    if not bool(legal_actions_unwrap.get("ok", false)):
        return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
    var legal_actions = legal_actions_unwrap.get("data", null)
    if not legal_actions.legal_ultimate_ids.has("kashimo_phantom_beast_amber"):
        return harness.fail_result("kashimo manager amber path should expose phantom beast amber after 3 regular casts")
    var amber_command = _helper.unwrap_ok(manager.build_command({
        "turn_index": 4,
        "command_type": CommandTypesScript.ULTIMATE,
        "command_source": "manual",
        "side_id": "P1",
        "actor_public_id": "P1-A",
        "skill_id": "kashimo_phantom_beast_amber",
    }), "build_command(kashimo_phantom_beast_amber)")
    if not bool(amber_command.get("ok", false)):
        return harness.fail_result(str(amber_command.get("error", "manager build_command failed")))
    var wait_turn_4 = _helper.unwrap_ok(manager.build_command({
        "turn_index": 4,
        "command_type": CommandTypesScript.WAIT,
        "command_source": "manual",
        "side_id": "P2",
        "actor_public_id": "P2-A",
    }), "build_command(wait turn4)")
    if not bool(wait_turn_4.get("ok", false)):
        return harness.fail_result(str(wait_turn_4.get("error", "manager build_command failed")))
    var amber_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
        amber_command.get("data", null),
        wait_turn_4.get("data", null),
    ]), "run_turn amber")
    if not bool(amber_turn_unwrap.get("ok", false)):
        return harness.fail_result(str(amber_turn_unwrap.get("error", "manager run_turn failed")))
    var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
    if not bool(public_snapshot_unwrap.get("ok", false)):
        return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
    var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
    var actor_snapshot := _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
    if actor_snapshot.is_empty():
        return harness.fail_result("kashimo manager amber path missing actor public snapshot")
    var stat_stages: Dictionary = actor_snapshot.get("stat_stages", {})
    if int(stat_stages.get("attack", 0)) != 2 or int(stat_stages.get("sp_attack", 0)) != 2 or int(stat_stages.get("speed", 0)) != 1:
        return harness.fail_result("kashimo manager amber path should expose persistent stat stages in public snapshot")
    if not _helper.unit_snapshot_has_effect(actor_snapshot, "kashimo_amber_bleed"):
        return harness.fail_result("kashimo manager amber path should expose amber bleed in public snapshot")
    if int(actor_snapshot.get("ultimate_points", -1)) != 0:
        return harness.fail_result("kashimo manager amber path should reset ultimate points after cast")
    var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
    if not bool(event_log_unwrap.get("ok", false)):
        return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
    var events: Array = event_log_unwrap.get("data", {}).get("events", [])
    if _helper.contains_runtime_id_leak(events):
        return harness.fail_result("kashimo manager amber path event log must stay public-safe")
    if not _helper.event_log_has_public_action_cast(events, "P1-A", "kashimo_hajime"):
        return harness.fail_result("kashimo manager amber path should expose kashimo public action cast")
    var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
    if not bool(close_unwrap.get("ok", false)):
        return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
    return harness.pass_result()
