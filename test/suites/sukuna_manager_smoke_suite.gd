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
				"test_name": "test_sukuna_manager_smoke_contract",
				"battle_seed": 1302,
				"build_battle_setup": Callable(self, "_build_sukuna_manager_smoke_setup"),
				"run_case": Callable(self, "_run_sukuna_manager_smoke_case"),
			},
			{
				"test_name": "test_sukuna_manager_domain_lifecycle_public_contract",
				"battle_seed": 1304,
				"build_battle_setup": Callable(self, "_build_sukuna_manager_domain_setup"),
				"run_case": Callable(self, "_run_sukuna_manager_domain_case"),
			},
		]

func before_test() -> void:
	_ensure_suite_state()

func test_sukuna_manager_public_contracts() -> void:
	_assert_legacy_result(_test_sukuna_manager_public_contracts(_harness))

func _test_sukuna_manager_public_contracts(harness) -> Dictionary:
	_ensure_suite_state()
	for raw_case_spec in _case_specs:
		var case_spec: Dictionary = raw_case_spec
		var result = _smoke_helper.run_case(harness, case_spec)
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()

func _build_sukuna_manager_smoke_setup(harness, sample_factory, _case_spec: Dictionary):
	var ritual_loadout := PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])
	var battle_setup = harness.build_sample_setup(sample_factory, {"P1": {0: ritual_loadout}})
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"])
	battle_setup.sides[0].starting_index = 0
	return battle_setup

func _build_sukuna_manager_domain_setup(harness, sample_factory, _case_spec: Dictionary):
	var battle_setup = harness.build_sample_setup(sample_factory)
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"])
	battle_setup.sides[0].starting_index = 0
	battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_mossaur", "sample_pyron", "sample_tidekit"])
	battle_setup.sides[1].starting_index = 0
	return battle_setup

func _run_sukuna_manager_smoke_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if String(legal_actions.actor_public_id) != "P1-A":
		return harness.fail_result("sukuna manager smoke should expose actor_public_id=P1-A")
	if not legal_actions.legal_skill_ids.has("sukuna_reverse_ritual"):
		return harness.fail_result("sukuna manager smoke should expose reverse ritual in legal actions")
	if legal_actions.legal_skill_ids.has("sukuna_hiraku"):
		return harness.fail_result("sukuna manager smoke should hide hiraku after loadout override")
	var setup_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn_setup",
		"p1_action": "wait",
		"p2_action": "sample_strike",
		"p1_label": "build_command(wait_p1)",
		"p2_label": "build_command(sample_strike)",
	})
	if not bool(setup_turn.get("ok", false)):
		return harness.fail_result(str(setup_turn.get("error", "manager setup run_turn failed")))
	var damaged_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot_after_damage")
	if not bool(damaged_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(damaged_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var damaged_actor_snapshot: Dictionary = _helper.find_unit_snapshot(damaged_snapshot_unwrap.get("data", {}), "P1", "P1-A")
	if damaged_actor_snapshot.is_empty():
		return harness.fail_result("sukuna manager smoke missing actor snapshot after setup turn")
	var before_hp := int(damaged_actor_snapshot.get("current_hp", -1))
	var max_hp := int(damaged_actor_snapshot.get("max_hp", -1))
	if before_hp <= 0 or max_hp <= 0 or before_hp >= max_hp:
		return harness.fail_result("sukuna manager smoke setup turn should leave actor damaged but alive")
	var expected_gain: int = min(max_hp - before_hp, max(1, int(floor(float(max_hp) * 0.25))))
	var heal_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 2,
		"label": "run_turn",
		"p1_action": "sukuna_reverse_ritual",
		"p2_action": "wait",
		"p1_label": "build_command(sukuna_reverse_ritual)",
		"p2_label": "build_command(wait)",
	})
	if not bool(heal_turn.get("ok", false)):
		return harness.fail_result(str(heal_turn.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var shape_error: String = _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("sukuna manager smoke public snapshot malformed: %s" % shape_error)
	var actor_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	if actor_snapshot.is_empty():
		return harness.fail_result("sukuna manager smoke missing actor public snapshot")
	if int(actor_snapshot.get("current_hp", -1)) != before_hp + expected_gain:
		return harness.fail_result("sukuna manager smoke public snapshot hp mismatch")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if events.is_empty():
		return harness.fail_result("sukuna manager smoke event log should not be empty after run_turn")
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna manager smoke event log must stay public-safe")
	if not _helper.event_log_has_public_heal(events, "P1-A"):
		return harness.fail_result("sukuna manager smoke event log should expose heal on P1-A")
	return harness.pass_result()

func _run_sukuna_manager_domain_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var charge_turns: Array = []
	for turn_index in [1, 2, 3]:
		charge_turns.append({
			"turn_index": turn_index,
			"label": "run_turn charge_sukuna",
			"p1_action": "sukuna_kai",
			"p2_action": "wait",
			"p1_label": "build_command(sukuna_kai)",
			"p2_label": "build_command(wait)",
		})
	var charge_result = _smoke_helper.run_turn_sequence_result(manager, session_id, charge_turns)
	if not bool(charge_result.get("ok", false)):
		return harness.fail_result(str(charge_result.get("error", "manager run_turn failed")))
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_ultimate_ids.has("sukuna_fukuma_mizushi"):
		return harness.fail_result("sukuna manager domain path should expose fukuma mizushi after 3 regular casts")
	var domain_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 4,
		"label": "run_turn domain",
		"p1_action": {"action_kind": "ultimate", "skill_id": "sukuna_fukuma_mizushi"},
		"p2_action": "wait",
		"p1_label": "build_command(sukuna_fukuma_mizushi)",
		"p2_label": "build_command(wait turn4)",
	})
	if not bool(domain_turn.get("ok", false)):
		return harness.fail_result(str(domain_turn.get("error", "manager run_turn failed")))
	var active_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot active_domain")
	if not bool(active_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(active_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var active_snapshot: Dictionary = active_snapshot_unwrap.get("data", {})
	if String(active_snapshot.get("field_id", "")) != "sukuna_malevolent_shrine_field":
		return harness.fail_result("sukuna manager domain path should expose active sukuna_malevolent_shrine_field")
	var turn_5 = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 5,
		"label": "run_turn turn5",
		"p1_action": "wait",
		"p2_action": "wait",
		"p1_label": "build_command(wait turn5 p1)",
		"p2_label": "build_command(wait turn5 p2)",
	})
	if not bool(turn_5.get("ok", false)):
		return harness.fail_result(str(turn_5.get("error", "manager run_turn failed")))
	var pre_expire_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot pre_expire")
	if not bool(pre_expire_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(pre_expire_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var pre_expire_target: Dictionary = _helper.find_unit_snapshot(pre_expire_snapshot_unwrap.get("data", {}), "P2", "P2-A")
	if pre_expire_target.is_empty():
		return harness.fail_result("sukuna manager domain path missing target snapshot before expire")
	var hp_before_expire := int(pre_expire_target.get("current_hp", -1))
	var turn_6 = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 6,
		"label": "run_turn turn6",
		"p1_action": "wait",
		"p2_action": "wait",
		"p1_label": "build_command(wait turn6 p1)",
		"p2_label": "build_command(wait turn6 p2)",
	})
	if not bool(turn_6.get("ok", false)):
		return harness.fail_result(str(turn_6.get("error", "manager run_turn failed")))
	var expired_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot expired_domain")
	if not bool(expired_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(expired_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var expired_snapshot: Dictionary = expired_snapshot_unwrap.get("data", {})
	if expired_snapshot.get("field_id", null) != null:
		return harness.fail_result("sukuna manager domain path should clear field after natural expire")
	var expired_target: Dictionary = _helper.find_unit_snapshot(expired_snapshot, "P2", "P2-A")
	if expired_target.is_empty():
		return harness.fail_result("sukuna manager domain path missing target snapshot after expire")
	if int(expired_target.get("current_hp", -1)) >= hp_before_expire:
		return harness.fail_result("sukuna manager domain path should expose expire burst damage on target snapshot")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna manager domain path event log must stay public-safe")
	return harness.pass_result()
