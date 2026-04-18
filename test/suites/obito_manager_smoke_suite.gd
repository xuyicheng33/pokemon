extends "res://test/support/gdunit_suite_bridge.gd"

const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var _smoke_helper = null
var _helper = null
var _support = ObitoTestSupportScript.new()
var _case_specs: Array = []

func _ensure_suite_state() -> void:
	if _smoke_helper == null or _helper == null:
		_smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
		_helper = _smoke_helper.contracts()
	if _case_specs.is_empty():
		_case_specs = [
			{
				"test_name": "test_obito_manager_smoke_contract",
				"battle_seed": 1550,
				"build_battle_setup": Callable(self, "_build_obito_manager_smoke_setup"),
				"run_case": Callable(self, "_run_obito_manager_smoke_case"),
			},
			{
				"test_name": "test_obito_manager_public_contract",
				"battle_seed": 1551,
				"build_battle_setup": Callable(self, "_build_obito_manager_public_setup"),
				"run_case": Callable(self, "_run_obito_manager_public_case"),
			},
		]

func before_test() -> void:
	_ensure_suite_state()

func test_obito_manager_smoke_contract() -> void:
	_assert_legacy_result(_test_obito_manager_smoke_contract(_harness))

func test_obito_manager_public_contract() -> void:
	_assert_legacy_result(_test_obito_manager_public_contract(_harness))

func _test_obito_manager_smoke_contract(harness) -> Dictionary:
	return _smoke_helper.run_named_case(harness, _case_specs, "test_obito_manager_smoke_contract")

func _test_obito_manager_public_contract(harness) -> Dictionary:
	return _smoke_helper.run_named_case(harness, _case_specs, "test_obito_manager_public_contract")

func _build_obito_manager_smoke_setup(harness, sample_factory, _case_spec: Dictionary):
	return harness.build_setup_by_matchup_id(sample_factory, "obito_vs_sample")

func _build_obito_manager_public_setup(_harness, sample_factory, _case_spec: Dictionary):
	return _support.build_obito_mirror_setup(sample_factory)

func _run_obito_manager_smoke_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if String(legal_actions.actor_public_id) != "P1-A":
		return harness.fail_result("obito manager smoke should expose actor_public_id=P1-A")
	if not legal_actions.legal_skill_ids.has("obito_qiudao_jiaotu"):
		return harness.fail_result("obito manager smoke legal actions should include obito_qiudao_jiaotu")
	if not legal_actions.legal_ultimate_ids.is_empty():
		return harness.fail_result("obito manager smoke turn 1 should not expose ultimate before points are charged")
	var run_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn",
		"p1_action": "obito_qiudao_jiaotu",
		"p2_action": "wait",
		"p1_label": "build_command(obito_qiudao_jiaotu)",
		"p2_label": "build_command(wait)",
	})
	if not bool(run_turn.get("ok", false)):
		return harness.fail_result(str(run_turn.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var shape_error: String = _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("obito manager smoke public snapshot malformed: %s" % shape_error)
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if target_snapshot.is_empty():
		return harness.fail_result("obito manager smoke missing target public snapshot")
	if not _helper.unit_snapshot_has_effect(target_snapshot, "obito_qiudao_jiaotu_heal_block_mark"):
		return harness.fail_result("obito manager smoke should expose heal block mark on P2-A")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("obito manager smoke event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "obito_juubi_jinchuriki"):
		return harness.fail_result("obito manager smoke event log should expose obito public action cast")
	return harness.pass_result()

func _run_obito_manager_public_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var charge_turns: Array = []
	for turn_index in [1, 2, 3]:
		charge_turns.append({
			"turn_index": turn_index,
			"label": "run_turn charge_obito",
			"p1_action": "obito_qiudao_jiaotu",
			"p2_action": "obito_yinyang_dun",
			"p1_label": "build_command(charge_obito_%d)" % turn_index,
			"p2_label": "build_command(defend_obito_%d)" % turn_index,
		})
	var charge_result = _smoke_helper.run_turn_sequence_result(manager, session_id, charge_turns)
	if not bool(charge_result.get("ok", false)):
		return harness.fail_result(str(charge_result.get("error", "manager run_turn failed")))
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_ultimate_ids.has("obito_shiwei_weishouyu"):
		return harness.fail_result("obito manager public path should expose ultimate after 3 regular casts")
	var pre_ultimate_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(pre_ultimate)")
	if not bool(pre_ultimate_log_unwrap.get("ok", false)):
		return harness.fail_result(str(pre_ultimate_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var pre_ultimate_total_size := int(pre_ultimate_log_unwrap.get("data", {}).get("total_size", 0))
	var ultimate_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 4,
		"label": "run_turn obito ultimate",
		"p1_action": {"action_kind": "ultimate", "skill_id": "obito_shiwei_weishouyu"},
		"p2_action": "wait",
		"p1_label": "build_command(obito_shiwei_weishouyu)",
		"p2_label": "build_command(wait turn4)",
	})
	if not bool(ultimate_turn.get("ok", false)):
		return harness.fail_result(str(ultimate_turn.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	if _helper.validate_snapshot_shape(public_snapshot) != "":
		return harness.fail_result("obito manager public path should keep snapshot shape stable")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot", pre_ultimate_total_size)
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
	return harness.pass_result()
