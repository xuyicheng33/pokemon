extends RefCounted
class_name FormalCharacterPairSmokeSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = null
var _helper = null

func register_tests(runner, failures: Array[String], harness) -> void:
    _ensure_helpers()
    runner.run_test("formal_pair_sukuna_vs_kashimo_manager_smoke_contract", failures, Callable(self, "_test_sukuna_vs_kashimo_manager_smoke_contract").bind(harness))
    runner.run_test("formal_pair_sukuna_vs_obito_manager_smoke_contract", failures, Callable(self, "_test_sukuna_vs_obito_manager_smoke_contract").bind(harness))
    runner.run_test("formal_pair_kashimo_vs_obito_manager_smoke_contract", failures, Callable(self, "_test_kashimo_vs_obito_manager_smoke_contract").bind(harness))

func _ensure_helpers() -> void:
    if _smoke_helper != null and _helper != null:
        return
    _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
    _helper = _smoke_helper.contracts()

func _test_sukuna_vs_kashimo_manager_smoke_contract(harness) -> Dictionary:
    var context: Dictionary = _smoke_helper.build_context(harness)
    if context.has("error"):
        return harness.fail_result(str(context["error"]))
    return _run_pair_case(
        harness,
        context["manager"],
        context["sample_factory"],
        1660,
        context["sample_factory"].build_sukuna_vs_kashimo_setup(),
        "sukuna_kai",
        "kashimo_charge",
        "sukuna",
        "kashimo_hajime"
    )

func _test_sukuna_vs_obito_manager_smoke_contract(harness) -> Dictionary:
    var context: Dictionary = _smoke_helper.build_context(harness)
    if context.has("error"):
        return harness.fail_result(str(context["error"]))
    return _run_pair_case(
        harness,
        context["manager"],
        context["sample_factory"],
        1661,
        context["sample_factory"].build_sukuna_vs_obito_setup(),
        "sukuna_kai",
        "obito_qiudao_jiaotu",
        "sukuna",
        "obito_juubi_jinchuriki"
    )

func _test_kashimo_vs_obito_manager_smoke_contract(harness) -> Dictionary:
    var context: Dictionary = _smoke_helper.build_context(harness)
    if context.has("error"):
        return harness.fail_result(str(context["error"]))
    return _run_pair_case(
        harness,
        context["manager"],
        context["sample_factory"],
        1662,
        context["sample_factory"].build_kashimo_vs_obito_setup(),
        "kashimo_raiken",
        "obito_yinyang_dun",
        "kashimo_hajime",
        "obito_juubi_jinchuriki"
    )

func _run_pair_case(
    harness,
    manager,
    sample_factory,
    battle_seed: int,
    battle_setup,
    p1_skill_id: String,
    p2_skill_id: String,
    p1_definition_id: String,
    p2_definition_id: String
) -> Dictionary:
    var init_unwrap = _smoke_helper.create_session(manager, sample_factory, battle_seed, battle_setup, "create_session(pair)")
    if not bool(init_unwrap.get("ok", false)):
        return harness.fail_result(str(init_unwrap.get("error", "pair create_session failed")))
    var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
    var p1_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions(P1)")
    if not bool(p1_actions_unwrap.get("ok", false)):
        return harness.fail_result(str(p1_actions_unwrap.get("error", "pair get_legal_actions P1 failed")))
    var p2_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P2"), "get_legal_actions(P2)")
    if not bool(p2_actions_unwrap.get("ok", false)):
        return harness.fail_result(str(p2_actions_unwrap.get("error", "pair get_legal_actions P2 failed")))
    var p1_actions = p1_actions_unwrap.get("data", null)
    var p2_actions = p2_actions_unwrap.get("data", null)
    if String(p1_actions.actor_public_id) != "P1-A" or String(p2_actions.actor_public_id) != "P2-A":
        return harness.fail_result("formal pair smoke should expose stable actor_public_id on both sides")
    if not p1_actions.legal_skill_ids.has(p1_skill_id):
        return harness.fail_result("formal pair smoke P1 should expose %s" % p1_skill_id)
    if not p2_actions.legal_skill_ids.has(p2_skill_id):
        return harness.fail_result("formal pair smoke P2 should expose %s" % p2_skill_id)
    var p1_command = _helper.unwrap_ok(manager.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": "P1",
        "actor_public_id": "P1-A",
        "skill_id": p1_skill_id,
    }), "build_command(P1)")
    if not bool(p1_command.get("ok", false)):
        return harness.fail_result(str(p1_command.get("error", "pair build_command P1 failed")))
    var p2_command = _helper.unwrap_ok(manager.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": "P2",
        "actor_public_id": "P2-A",
        "skill_id": p2_skill_id,
    }), "build_command(P2)")
    if not bool(p2_command.get("ok", false)):
        return harness.fail_result(str(p2_command.get("error", "pair build_command P2 failed")))
    var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
        p1_command.get("data", null),
        p2_command.get("data", null),
    ]), "run_turn(pair)")
    if not bool(run_turn_unwrap.get("ok", false)):
        return harness.fail_result(str(run_turn_unwrap.get("error", "pair run_turn failed")))
    var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(pair)")
    if not bool(public_snapshot_unwrap.get("ok", false)):
        return harness.fail_result(str(public_snapshot_unwrap.get("error", "pair get_public_snapshot failed")))
    var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
    var shape_error: String = _helper.validate_snapshot_shape(public_snapshot)
    if not shape_error.is_empty():
        return harness.fail_result("formal pair smoke public snapshot malformed: %s" % shape_error)
    var p1_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
    var p2_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
    if String(p1_snapshot.get("definition_id", "")) != p1_definition_id:
        return harness.fail_result("formal pair smoke P1 definition drifted: expected %s" % p1_definition_id)
    if String(p2_snapshot.get("definition_id", "")) != p2_definition_id:
        return harness.fail_result("formal pair smoke P2 definition drifted: expected %s" % p2_definition_id)
    var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(pair)")
    if not bool(event_log_unwrap.get("ok", false)):
        return harness.fail_result(str(event_log_unwrap.get("error", "pair get_event_log_snapshot failed")))
    var events: Array = event_log_unwrap.get("data", {}).get("events", [])
    if events.is_empty():
        return harness.fail_result("formal pair smoke event log should not be empty after both formal roles act")
    if _helper.contains_runtime_id_leak(events):
        return harness.fail_result("formal pair smoke event log must stay public-safe")
    if not _helper.event_log_has_public_action_cast(events, "P1-A", p1_definition_id):
        return harness.fail_result("formal pair smoke should expose P1 public action cast")
    if not _helper.event_log_has_public_action_cast(events, "P2-A", p2_definition_id):
        return harness.fail_result("formal pair smoke should expose P2 public action cast")
    var close_unwrap = _smoke_helper.close_session(manager, session_id, "close_session(pair)")
    if not bool(close_unwrap.get("ok", false)):
        return harness.fail_result(str(close_unwrap.get("error", "pair close_session failed")))
    return harness.pass_result()
