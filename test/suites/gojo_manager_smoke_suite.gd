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
				"test_name": "test_gojo_manager_smoke_contract",
				"battle_seed": 1301,
				"build_battle_setup": Callable(self, "_build_gojo_manager_smoke_setup"),
				"run_case": Callable(self, "_run_gojo_manager_smoke_case"),
			},
			{
				"test_name": "test_gojo_manager_domain_public_contract",
				"battle_seed": 1303,
				"build_battle_setup": Callable(self, "_build_gojo_manager_domain_setup"),
				"run_case": Callable(self, "_run_gojo_manager_domain_case"),
			},
		]


func before_test() -> void:
	_ensure_suite_state()


func test_gojo_manager_public_contracts() -> void:
	_assert_legacy_result(_test_gojo_manager_public_contracts(_harness))


func _test_gojo_manager_public_contracts(harness) -> Dictionary:
	_ensure_suite_state()
	for raw_case_spec in _case_specs:
		var case_spec: Dictionary = raw_case_spec
		var result = _smoke_helper.run_case(harness, case_spec)
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()


func _build_gojo_manager_smoke_setup(harness, sample_factory, _case_spec: Dictionary):
	var ritual_loadout := PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
	return harness.build_setup_by_matchup_id(sample_factory, "gojo_vs_sample", {"P1": {0: ritual_loadout}})


func _build_gojo_manager_domain_setup(harness, sample_factory, _case_spec: Dictionary):
	var battle_setup = harness.build_sample_setup(sample_factory)
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"])
	battle_setup.sides[0].starting_index = 0
	battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_mossaur", "sample_pyron", "sample_tidekit"])
	battle_setup.sides[1].starting_index = 0
	return battle_setup


func _run_gojo_manager_smoke_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if String(legal_actions.actor_public_id) != "P1-A":
		return harness.fail_result("gojo manager smoke should expose actor_public_id=P1-A")
	if not legal_actions.legal_skill_ids.has("gojo_reverse_ritual"):
		return harness.fail_result("gojo manager smoke should expose reverse ritual in legal actions")
	if legal_actions.legal_skill_ids.has("gojo_murasaki"):
		return harness.fail_result("gojo manager smoke should hide murasaki after loadout override")
	var first_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn turn1",
		"p1_action": "wait",
		"p2_action": "sample_strike",
		"p1_label": "build_command(wait p1)",
		"p2_label": "build_command(sample_strike)",
	})
	if not bool(first_turn.get("ok", false)):
		return harness.fail_result(str(first_turn.get("error", "manager run_turn failed")))
	var damaged_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot")
	if not bool(damaged_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(damaged_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var damaged_snapshot: Dictionary = damaged_snapshot_unwrap.get("data", {})
	var damaged_actor_snapshot: Dictionary = _helper.find_unit_snapshot(damaged_snapshot, "P1", "P1-A")
	if damaged_actor_snapshot.is_empty():
		return harness.fail_result("gojo manager smoke missing actor public snapshot after damage")
	var damaged_hp := int(damaged_actor_snapshot.get("current_hp", -1))
	var max_hp := int(damaged_actor_snapshot.get("max_hp", -1))
	if damaged_hp <= 0 or max_hp <= 0 or damaged_hp >= max_hp:
		return harness.fail_result("gojo manager smoke should show damaged hp after turn 1")
	var second_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 2,
		"label": "run_turn turn2",
		"p1_action": "gojo_reverse_ritual",
		"p2_action": "wait",
		"p1_label": "build_command(gojo_reverse_ritual)",
		"p2_label": "build_command(wait p2)",
	})
	if not bool(second_turn.get("ok", false)):
		return harness.fail_result(str(second_turn.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var shape_error: String = _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("gojo manager smoke public snapshot malformed: %s" % shape_error)
	var actor_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	if actor_snapshot.is_empty():
		return harness.fail_result("gojo manager smoke missing actor public snapshot")
	if int(actor_snapshot.get("current_hp", -1)) <= damaged_hp:
		return harness.fail_result("gojo manager smoke should heal after reverse ritual")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if events.is_empty():
		return harness.fail_result("gojo manager smoke event log should not be empty after run_turn")
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("gojo manager smoke event log must stay public-safe")
	if not _helper.event_log_has_public_heal(events, "P1-A"):
		return harness.fail_result("gojo manager smoke event log should expose heal on P1-A")
	return harness.pass_result()


func _run_gojo_manager_domain_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var charge_turns: Array = []
	for turn_index in [1, 2, 3]:
		charge_turns.append({
			"turn_index": turn_index,
			"label": "run_turn charge_gojo",
			"p1_action": "gojo_ao",
			"p2_action": "wait",
			"p1_label": "build_command(gojo_ao)",
			"p2_label": "build_command(wait)",
		})
	var charge_result = _smoke_helper.run_turn_sequence_result(manager, session_id, charge_turns)
	if not bool(charge_result.get("ok", false)):
		return harness.fail_result(str(charge_result.get("error", "manager run_turn failed")))
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_ultimate_ids.has("gojo_unlimited_void"):
		return harness.fail_result("gojo manager domain path should expose unlimited void after 3 regular casts")
	var domain_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 4,
		"label": "run_turn domain",
		"p1_action": {"action_kind": "ultimate", "skill_id": "gojo_unlimited_void"},
		"p2_action": "wait",
		"p1_label": "build_command(gojo_unlimited_void)",
		"p2_label": "build_command(wait turn4)",
	})
	if not bool(domain_turn.get("ok", false)):
		return harness.fail_result(str(domain_turn.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	if String(public_snapshot.get("field_id", "")) != "gojo_unlimited_void_field":
		return harness.fail_result("gojo manager domain path should expose active gojo_unlimited_void_field")
	var field_snapshot: Dictionary = public_snapshot.get("field", {})
	if String(field_snapshot.get("creator_public_id", "")) != "P1-A":
		return harness.fail_result("gojo manager domain path should expose P1-A as field creator")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("gojo manager domain path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "gojo_satoru"):
		return harness.fail_result("gojo manager domain path should expose gojo public action cast")
	return harness.pass_result()
