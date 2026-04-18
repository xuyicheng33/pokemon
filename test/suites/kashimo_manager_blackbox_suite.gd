extends "res://test/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
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
				"test_name": "test_kashimo_manager_water_leak_public_contract",
				"battle_seed": 1341,
				"create_label": "create_session(kashimo water leak)",
				"close_label": "close_session(kashimo water leak)",
				"build_battle_setup": Callable(self, "_build_kashimo_default_setup"),
				"run_case": Callable(self, "_run_kashimo_manager_water_leak_case"),
			},
			{
				"test_name": "test_kashimo_manager_feedback_strike_public_contract",
				"battle_seed": 1342,
				"create_label": "create_session(kashimo feedback strike)",
				"close_label": "close_session(kashimo feedback)",
				"build_battle_setup": Callable(self, "_build_kashimo_default_setup"),
				"run_case": Callable(self, "_run_kashimo_manager_feedback_case"),
			},
			{
				"test_name": "test_kashimo_manager_kyokyo_public_contract",
				"battle_seed": 1343,
				"create_label": "create_session(kashimo kyokyo)",
				"close_label": "close_session(kashimo kyokyo)",
				"build_battle_setup": Callable(self, "_build_kashimo_kyokyo_setup"),
				"run_case": Callable(self, "_run_kashimo_manager_kyokyo_case"),
			},
		]

func before_test() -> void:
	_ensure_suite_state()

func test_kashimo_manager_water_leak_public_contract() -> void:
	_assert_legacy_result(_test_kashimo_manager_water_leak_public_contract(_harness))

func test_kashimo_manager_feedback_strike_public_contract() -> void:
	_assert_legacy_result(_test_kashimo_manager_feedback_strike_public_contract(_harness))

func test_kashimo_manager_kyokyo_public_contract() -> void:
	_assert_legacy_result(_test_kashimo_manager_kyokyo_public_contract(_harness))

func _test_kashimo_manager_water_leak_public_contract(harness) -> Dictionary:
	return _smoke_helper.run_named_case(harness, _case_specs, "test_kashimo_manager_water_leak_public_contract")

func _test_kashimo_manager_feedback_strike_public_contract(harness) -> Dictionary:
	return _smoke_helper.run_named_case(harness, _case_specs, "test_kashimo_manager_feedback_strike_public_contract")

func _test_kashimo_manager_kyokyo_public_contract(harness) -> Dictionary:
	return _smoke_helper.run_named_case(harness, _case_specs, "test_kashimo_manager_kyokyo_public_contract")

func _build_kashimo_default_setup(harness, sample_factory, _case_spec: Dictionary):
	return harness.build_setup_by_matchup_id(sample_factory, "kashimo_vs_sample")

func _build_kashimo_kyokyo_setup(harness, sample_factory, _case_spec: Dictionary):
	var override_loadout := {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])}
	return harness.build_setup_by_matchup_id(sample_factory, "kashimo_vs_sample", {"P1": override_loadout})

func _run_kashimo_manager_water_leak_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var before_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(kashimo water leak before)")
	if not bool(before_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(before_snapshot_unwrap.get("error", "kashimo water leak pre snapshot failed")))
	var before_snapshot: Dictionary = before_snapshot_unwrap.get("data", {})
	var before_kashimo: Dictionary = _helper.find_unit_snapshot(before_snapshot, "P1", "P1-A")
	var before_attacker: Dictionary = _helper.find_unit_snapshot(before_snapshot, "P2", "P2-A")
	var before_mp := int(before_kashimo.get("current_mp", -1))
	var before_attacker_hp := int(before_attacker.get("current_hp", -1))
	var run_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn(kashimo water leak)",
		"p1_action": "wait",
		"p2_action": "sample_tide_surge",
		"p1_label": "build_command(kashimo wait)",
		"p2_label": "build_command(sample_tide_surge)",
	})
	if not bool(run_turn.get("ok", false)):
		return harness.fail_result(str(run_turn.get("error", "kashimo water leak run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(kashimo water leak)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "kashimo water leak snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var kashimo_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	var attacker_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if before_mp - int(kashimo_snapshot.get("current_mp", -1)) != 15:
		return harness.fail_result("kashimo manager water leak path should reduce current_mp by exactly 15")
	if int(attacker_snapshot.get("current_hp", -1)) >= before_attacker_hp:
		return harness.fail_result("kashimo manager water leak path should counter-damage the water attacker")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(kashimo water leak)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "kashimo water leak event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("kashimo manager water leak path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P2-A", "sample_tidekit"):
		return harness.fail_result("kashimo manager water leak path should expose attacker public action cast")
	return harness.pass_result()

func _run_kashimo_manager_feedback_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var setup_turns: Array = [
		{
			"turn_index": 1,
			"label": "run_turn(kashimo feedback setup)",
			"p1_action": "kashimo_raiken",
			"p2_action": "wait",
			"p1_label": "build_command(kashimo_raiken)",
			"p2_label": "build_command(wait)",
		},
		{
			"turn_index": 2,
			"label": "run_turn(kashimo feedback setup)",
			"p1_action": "kashimo_charge",
			"p2_action": "wait",
			"p1_label": "build_command(kashimo_charge)",
			"p2_label": "build_command(wait)",
		},
	]
	var setup_result = _smoke_helper.run_turn_sequence_result(manager, session_id, setup_turns)
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result(str(setup_result.get("error", "kashimo feedback setup run_turn failed")))
	var before_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(kashimo feedback before)")
	if not bool(before_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(before_snapshot_unwrap.get("error", "kashimo feedback pre snapshot failed")))
	var before_snapshot: Dictionary = before_snapshot_unwrap.get("data", {})
	var actor_before: Dictionary = _helper.find_unit_snapshot(before_snapshot, "P1", "P1-A")
	var target_before: Dictionary = _helper.find_unit_snapshot(before_snapshot, "P2", "P2-A")
	if not _helper.unit_snapshot_has_effect(actor_before, "kashimo_positive_charge_mark"):
		return harness.fail_result("kashimo feedback public path should expose positive charge before cast")
	if not _helper.unit_snapshot_has_effect(target_before, "kashimo_negative_charge_mark"):
		return harness.fail_result("kashimo feedback public path should expose negative charge before cast")
	var target_hp_before := int(target_before.get("current_hp", -1))
	var feedback_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 3,
		"label": "run_turn(kashimo feedback)",
		"p1_action": "kashimo_feedback_strike",
		"p2_action": "wait",
		"p1_label": "build_command(kashimo_feedback_strike)",
		"p2_label": "build_command(wait turn3)",
	})
	if not bool(feedback_turn.get("ok", false)):
		return harness.fail_result(str(feedback_turn.get("error", "kashimo feedback run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(kashimo feedback)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "kashimo feedback snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var actor_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if _helper.unit_snapshot_has_effect(actor_snapshot, "kashimo_positive_charge_mark"):
		return harness.fail_result("kashimo feedback public path should clear positive charge after cast")
	if _helper.unit_snapshot_has_effect(target_snapshot, "kashimo_negative_charge_mark"):
		return harness.fail_result("kashimo feedback public path should clear negative charge after cast")
	if int(target_snapshot.get("current_hp", -1)) >= target_hp_before:
		return harness.fail_result("kashimo feedback public path should damage the target")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(kashimo feedback)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "kashimo feedback event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("kashimo feedback public path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "kashimo_hajime"):
		return harness.fail_result("kashimo feedback public path should expose kashimo public action cast")
	return harness.pass_result()

func _run_kashimo_manager_kyokyo_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions(kashimo kyokyo)")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "kashimo kyokyo legal actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_skill_ids.has("kashimo_kyokyo_katsura"):
		return harness.fail_result("kashimo kyokyo public path should expose 弥虚葛笼 in legal actions")
	var run_turn = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn(kashimo kyokyo)",
		"p1_action": "kashimo_kyokyo_katsura",
		"p2_action": "wait",
		"p1_label": "build_command(kashimo_kyokyo_katsura)",
		"p2_label": "build_command(wait)",
	})
	if not bool(run_turn.get("ok", false)):
		return harness.fail_result(str(run_turn.get("error", "kashimo kyokyo run_turn failed")))
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(kashimo kyokyo)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "kashimo kyokyo event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	var has_nullify_apply := false
	for event_snapshot in events:
		if String(event_snapshot.get("event_type", "")) != EventTypesScript.EFFECT_RULE_MOD_APPLY:
			continue
		if String(event_snapshot.get("target_public_id", "")) != "P1-A":
			continue
		if String(event_snapshot.get("payload_summary", "")).find("nullify_field_accuracy") == -1:
			continue
		has_nullify_apply = true
		break
	if not has_nullify_apply:
		return harness.fail_result("kashimo kyokyo public path should expose nullify_field_accuracy apply in public event log")
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("kashimo kyokyo public path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "kashimo_hajime"):
		return harness.fail_result("kashimo kyokyo public path should expose kashimo public action cast")
	return harness.pass_result()
