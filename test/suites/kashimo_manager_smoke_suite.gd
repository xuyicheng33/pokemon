extends "res://test/support/gdunit_suite_bridge.gd"

const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _smoke_helper = null
var _helper = null
var _support = KashimoTestSupportScript.new()
var _case_specs: Array = []


func _ensure_suite_state() -> void:
	if _smoke_helper == null or _helper == null:
		_smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
		_helper = _smoke_helper.contracts()
	if _case_specs.is_empty():
		_case_specs = [
			{
				"test_name": "test_kashimo_manager_smoke_contract",
				"battle_seed": 1310,
				"build_battle_setup": Callable(self, "_build_kashimo_manager_smoke_setup"),
				"run_case": Callable(self, "_run_kashimo_manager_smoke_case"),
			},
			{
				"test_name": "test_kashimo_manager_amber_public_contract",
				"battle_seed": 1311,
				"build_battle_setup": Callable(self, "_build_kashimo_manager_amber_setup"),
				"run_case": Callable(self, "_run_kashimo_manager_amber_case"),
			},
		]


func before_test() -> void:
	_ensure_suite_state()


func test_kashimo_manager_smoke_contract() -> void:
	_assert_legacy_result(_test_kashimo_manager_smoke_contract(_harness))


func test_kashimo_manager_amber_public_contract() -> void:
	_assert_legacy_result(_test_kashimo_manager_amber_public_contract(_harness))


func _test_kashimo_manager_smoke_contract(harness) -> Dictionary:
	return _smoke_helper.run_named_case(harness, _case_specs, "test_kashimo_manager_smoke_contract")


func _test_kashimo_manager_amber_public_contract(harness) -> Dictionary:
	return _smoke_helper.run_named_case(harness, _case_specs, "test_kashimo_manager_amber_public_contract")


func _build_kashimo_manager_smoke_setup(_harness, sample_factory, _case_spec: Dictionary):
	return _support.build_kashimo_setup(sample_factory)


func _build_kashimo_manager_amber_setup(_harness, sample_factory, _case_spec: Dictionary):
	var battle_setup = _support.build_kashimo_setup(sample_factory)
	battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_mossaur", "sample_pyron", "sample_tidekit"])
	battle_setup.sides[1].starting_index = 0
	return battle_setup


func _run_kashimo_manager_smoke_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if String(legal_actions.actor_public_id) != "P1-A":
		return harness.fail_result("kashimo manager smoke should expose actor_public_id=P1-A")
	if not legal_actions.legal_skill_ids.has("kashimo_raiken"):
		return harness.fail_result("kashimo manager smoke legal actions should include kashimo_raiken")
	if not legal_actions.legal_ultimate_ids.is_empty():
		return harness.fail_result("kashimo manager smoke turn 1 should not expose ultimate before points are charged")
	var run_turn_result = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn",
		"p1_action": "kashimo_raiken",
		"p2_action": "wait",
		"p1_label": "build_command(kashimo_raiken)",
		"p2_label": "build_command(wait)",
	})
	if not bool(run_turn_result.get("ok", false)):
		return harness.fail_result(str(run_turn_result.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var shape_error: String = _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("kashimo manager smoke public snapshot malformed: %s" % shape_error)
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if target_snapshot.is_empty():
		return harness.fail_result("kashimo manager smoke missing target public snapshot")
	if not _helper.unit_snapshot_has_effect(target_snapshot, "kashimo_negative_charge_mark"):
		return harness.fail_result("kashimo manager smoke should expose negative charge on P2-A")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if events.is_empty():
		return harness.fail_result("kashimo manager smoke event log should not be empty after run_turn")
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("kashimo manager smoke event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "kashimo_hajime"):
		return harness.fail_result("kashimo manager smoke event log should expose kashimo public action cast")
	return harness.pass_result()


func _run_kashimo_manager_amber_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var charge_turns: Array = []
	for turn_index in [1, 2, 3]:
		charge_turns.append({
			"turn_index": turn_index,
			"label": "run_turn charge_kashimo",
			"p1_action": "kashimo_charge",
			"p2_action": "wait",
			"p1_label": "build_command(kashimo_charge)",
			"p2_label": "build_command(wait)",
		})
	var charge_result = _smoke_helper.run_turn_sequence_result(manager, session_id, charge_turns)
	if not bool(charge_result.get("ok", false)):
		return harness.fail_result(str(charge_result.get("error", "manager run_turn failed")))
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_ultimate_ids.has("kashimo_phantom_beast_amber"):
		return harness.fail_result("kashimo manager amber path should expose phantom beast amber after 3 regular casts")
	var amber_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 4,
		"label": "run_turn amber",
		"p1_action": {"action_kind": "ultimate", "skill_id": "kashimo_phantom_beast_amber"},
		"p2_action": "wait",
		"p1_label": "build_command(kashimo_phantom_beast_amber)",
		"p2_label": "build_command(wait turn4)",
	})
	if not bool(amber_turn.get("ok", false)):
		return harness.fail_result(str(amber_turn.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var actor_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	if actor_snapshot.is_empty():
		return harness.fail_result("kashimo manager amber path missing actor public snapshot")
	var stat_stages: Dictionary = actor_snapshot.get("stat_stages", {})
	if int(stat_stages.get("attack", 0)) != 2 or int(stat_stages.get("sp_attack", 0)) != 2 or int(stat_stages.get("speed", 0)) != 1:
		return harness.fail_result("kashimo manager amber path should expose persistent stat stages in public snapshot")
	if not _helper.unit_snapshot_has_effect(actor_snapshot, "kashimo_amber_bleed"):
		return harness.fail_result("kashimo manager amber path should expose amber bleed in public snapshot")
	if int(actor_snapshot.get("ultimate_points", -1)) != 0:
		return harness.fail_result("kashimo manager amber path should reset ultimate points after cast")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("kashimo manager amber path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "kashimo_hajime"):
		return harness.fail_result("kashimo manager amber path should expose kashimo public action cast")
	return harness.pass_result()
