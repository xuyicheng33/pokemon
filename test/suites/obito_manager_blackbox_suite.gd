extends "res://test/support/gdunit_suite_bridge.gd"

const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = null
var _helper = null
var _case_specs: Array = []

func _ensure_suite_state() -> void:
	if _smoke_helper == null or _helper == null:
		_smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
		_helper = _smoke_helper.contracts()
	if _case_specs.is_empty():
		_case_specs = [
			{
				"test_name": "test_obito_manager_fenghuo_public_contract",
				"battle_seed": 1351,
				"create_label": "create_session(obito fenghuo)",
				"close_label": "close_session(obito fenghuo)",
				"build_battle_setup": Callable(self, "_build_obito_fenghuo_setup"),
				"run_case": Callable(self, "_run_obito_manager_fenghuo_case"),
			},
			{
				"test_name": "test_obito_manager_yinyang_public_contract",
				"battle_seed": 1352,
				"create_label": "create_session(obito yinyang)",
				"close_label": "close_session(obito yinyang)",
				"build_battle_setup": Callable(self, "_build_obito_yinyang_setup"),
				"run_case": Callable(self, "_run_obito_manager_yinyang_case"),
			},
		]

func before_test() -> void:
	_ensure_suite_state()

func test_obito_manager_blackbox_contracts() -> void:
	_assert_legacy_result(_test_obito_manager_blackbox_contracts(_harness))

func _test_obito_manager_blackbox_contracts(harness) -> Dictionary:
	_ensure_suite_state()
	for raw_case_spec in _case_specs:
		var case_spec: Dictionary = raw_case_spec
		var result = _smoke_helper.run_case(harness, case_spec)
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()

func _build_obito_fenghuo_setup(harness, sample_factory, _case_spec: Dictionary):
	var override_loadout := {"P1": {0: PackedStringArray(["obito_qiudao_jiaotu", "obito_yinyang_dun", "obito_liudao_shizi_fenghuo"])}}
	return harness.build_setup_by_matchup_id(sample_factory, "obito_vs_sample", override_loadout)

func _build_obito_yinyang_setup(harness, sample_factory, _case_spec: Dictionary):
	return harness.build_setup_by_matchup_id(sample_factory, "obito_vs_sample")

func _run_obito_manager_fenghuo_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions(obito fenghuo)")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "obito fenghuo legal actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_skill_ids.has("obito_liudao_shizi_fenghuo"):
		return harness.fail_result("obito fenghuo manager path should expose liudao shizi fenghuo after loadout override")
	if legal_actions.legal_skill_ids.has("obito_qiudao_yu"):
		return harness.fail_result("obito fenghuo manager path should swap out qiudao yu from the current loadout")
	var run_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn(obito fenghuo)",
		"p1_action": "obito_liudao_shizi_fenghuo",
		"p2_action": "wait",
		"p1_label": "build_command(obito fenghuo)",
		"p2_label": "build_command(obito fenghuo wait)",
	})
	if not bool(run_turn.get("ok", false)):
		return harness.fail_result(str(run_turn.get("error", "obito fenghuo run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(obito fenghuo)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "obito fenghuo snapshot failed")))
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot_unwrap.get("data", {}), "P2", "P2-A")
	if int(target_snapshot.get("current_hp", -1)) >= int(target_snapshot.get("max_hp", -1)):
		return harness.fail_result("obito fenghuo manager path should deal real runtime damage to the target")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(obito fenghuo)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "obito fenghuo event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("obito fenghuo manager path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "obito_juubi_jinchuriki"):
		return harness.fail_result("obito fenghuo manager path should expose obito public action cast")
	return harness.pass_result()

func _run_obito_manager_yinyang_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var run_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn(obito yinyang)",
		"p1_action": "obito_yinyang_dun",
		"p2_action": "sample_strike",
		"p1_label": "build_command(obito yinyang)",
		"p2_label": "build_command(sample strike vs obito)",
	})
	if not bool(run_turn.get("ok", false)):
		return harness.fail_result(str(run_turn.get("error", "obito yinyang run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(obito yinyang)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "obito yinyang snapshot failed")))
	var actor_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot_unwrap.get("data", {}), "P1", "P1-A")
	var stat_stages: Dictionary = actor_snapshot.get("stat_stages", {})
	if int(stat_stages.get("defense", 0)) < 1 or int(stat_stages.get("sp_defense", 0)) < 1:
		return harness.fail_result("obito yinyang manager path should expose defense-side stat boosts in public snapshot")
	if not _helper.unit_snapshot_has_effect(actor_snapshot, "obito_yinyang_zhili"):
		return harness.fail_result("obito yinyang manager path should expose yinyang stacks in public snapshot")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(obito yinyang)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "obito yinyang event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("obito yinyang manager path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "obito_juubi_jinchuriki"):
		return harness.fail_result("obito yinyang manager path should expose obito public action cast")
	return harness.pass_result()
