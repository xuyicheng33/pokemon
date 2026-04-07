extends RefCounted
class_name ObitoManagerBlackboxSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
var _helper = _smoke_helper.contracts()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("obito_manager_fenghuo_public_contract", failures, Callable(self, "_test_obito_manager_fenghuo_public_contract").bind(harness))
	runner.run_test("obito_manager_yinyang_public_contract", failures, Callable(self, "_test_obito_manager_yinyang_public_contract").bind(harness))

func _test_obito_manager_fenghuo_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var override_loadout := {"P1": {0: PackedStringArray(["obito_qiudao_jiaotu", "obito_yinyang_dun", "obito_liudao_shizi_fenghuo"])}}
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "obito_vs_sample", override_loadout)
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1351, battle_setup, "create_session(obito fenghuo)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "obito fenghuo create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions(obito fenghuo)")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "obito fenghuo legal actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_skill_ids.has("obito_liudao_shizi_fenghuo"):
		return harness.fail_result("obito fenghuo manager path should expose liudao shizi fenghuo after loadout override")
	if legal_actions.legal_skill_ids.has("obito_qiudao_yu"):
		return harness.fail_result("obito fenghuo manager path should swap out qiudao yu from the current loadout")
	var strike_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "obito_liudao_shizi_fenghuo",
	}), "build_command(obito fenghuo)")
	var wait_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command(obito fenghuo wait)")
	if not bool(strike_command.get("ok", false)) or not bool(wait_command.get("ok", false)):
		return harness.fail_result("obito fenghuo manager path should build commands cleanly")
	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		strike_command.get("data", null),
		wait_command.get("data", null),
	]), "run_turn(obito fenghuo)")
	if not bool(run_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(run_turn_unwrap.get("error", "obito fenghuo run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(obito fenghuo)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "obito fenghuo snapshot failed")))
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot_unwrap.get("data", {}), "P2", "P2-A")
	if int(target_snapshot.get("current_hp", -1)) >= int(target_snapshot.get("max_hp", -1)):
		return harness.fail_result("obito fenghuo manager path should deal real runtime damage to the target")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(obito fenghuo)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "obito fenghuo event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("obito fenghuo manager path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "obito_juubi_jinchuriki"):
		return harness.fail_result("obito fenghuo manager path should expose obito public action cast")
	_smoke_helper.close_session(manager, session_id, "close_session(obito fenghuo)")
	return harness.pass_result()

func _test_obito_manager_yinyang_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "obito_vs_sample")
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1352, battle_setup, "create_session(obito yinyang)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "obito yinyang create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var yinyang_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "obito_yinyang_dun",
	}), "build_command(obito yinyang)")
	var strike_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
		"skill_id": "sample_strike",
	}), "build_command(sample strike vs obito)")
	if not bool(yinyang_command.get("ok", false)) or not bool(strike_command.get("ok", false)):
		return harness.fail_result("obito yinyang manager path should build commands cleanly")
	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		yinyang_command.get("data", null),
		strike_command.get("data", null),
	]), "run_turn(obito yinyang)")
	if not bool(run_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(run_turn_unwrap.get("error", "obito yinyang run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(obito yinyang)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "obito yinyang snapshot failed")))
	var actor_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot_unwrap.get("data", {}), "P1", "P1-A")
	var stat_stages: Dictionary = actor_snapshot.get("stat_stages", {})
	if int(stat_stages.get("defense", 0)) < 1 or int(stat_stages.get("sp_defense", 0)) < 1:
		return harness.fail_result("obito yinyang manager path should expose defense-side stat boosts in public snapshot")
	if not _helper.unit_snapshot_has_effect(actor_snapshot, "obito_yinyang_zhili"):
		return harness.fail_result("obito yinyang manager path should expose yinyang stacks in public snapshot")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(obito yinyang)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "obito yinyang event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("obito yinyang manager path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "obito_juubi_jinchuriki"):
		return harness.fail_result("obito yinyang manager path should expose obito public action cast")
	_smoke_helper.close_session(manager, session_id, "close_session(obito yinyang)")
	return harness.pass_result()
