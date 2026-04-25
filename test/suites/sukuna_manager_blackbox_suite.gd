extends "res://test/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")
const SukunaSetupRegenTestSupportScript := preload("res://tests/support/sukuna_setup_regen_test_support.gd")

var _smoke_helper = null
var _helper = null
var _support = SukunaSetupRegenTestSupportScript.new()
var _case_specs: Array = []

func _ensure_suite_state() -> void:
	if _smoke_helper == null or _helper == null:
		_smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
		_helper = _smoke_helper.contracts()
	if _case_specs.is_empty():
		_case_specs = [
			{
				"test_name": "test_sukuna_manager_kamado_on_exit_public_contract",
				"battle_seed": 1331,
				"create_label": "create_session(sukuna kamado)",
				"close_label": "close_session(sukuna kamado)",
				"build_battle_setup": Callable(self, "_build_sukuna_setup_setup"),
				"run_case": Callable(self, "_run_sukuna_manager_kamado_case"),
			},
			{
				"test_name": "test_sukuna_manager_hatsu_public_contract",
				"battle_seed": 1332,
				"create_label": "create_session(sukuna hatsu)",
				"close_label": "close_session(sukuna hatsu)",
				"build_battle_setup": Callable(self, "_build_sukuna_setup_setup"),
				"run_case": Callable(self, "_run_sukuna_manager_hatsu_case"),
			},
			{
				"test_name": "test_sukuna_manager_teach_love_public_contract",
				"battle_seed": 1333,
				"create_label": "create_session(sukuna teach love)",
				"close_label": "close_session(sukuna teach love)",
				"build_battle_setup": Callable(self, "_build_sukuna_teach_love_setup"),
				"run_case": Callable(self, "_run_sukuna_manager_teach_love_case"),
			},
		]

func before_test() -> void:
	_ensure_suite_state()

func test_sukuna_manager_blackbox_contracts() -> void:
	_assert_legacy_result(_test_sukuna_manager_blackbox_contracts(_harness))

func _test_sukuna_manager_blackbox_contracts(harness) -> Dictionary:
	_ensure_suite_state()
	for raw_case_spec in _case_specs:
		var case_spec: Dictionary = raw_case_spec
		var result = _smoke_helper.run_case(harness, case_spec)
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()

func _build_sukuna_setup_setup(harness, sample_factory, _case_spec: Dictionary):
	return harness.build_setup_by_matchup_id(sample_factory, "sukuna_setup")

func _build_sukuna_teach_love_setup(harness, sample_factory, _case_spec: Dictionary):
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "sukuna_setup")
	battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_tidekit", "gojo_satoru", "sample_mossaur"])
	battle_setup.sides[1].starting_index = 0
	return battle_setup

func _run_sukuna_manager_kamado_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var turn_one = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn(sukuna kamado)",
		"p1_action": "sukuna_hiraku",
		"p2_action": "wait",
		"p1_label": "build_command(sukuna kamado)",
		"p2_label": "build_command(sukuna kamado)",
	})
	if not bool(turn_one.get("ok", false)):
		return harness.fail_result(str(turn_one.get("error", "sukuna kamado turn1 failed")))
	var pre_switch_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(sukuna kamado pre-switch)")
	if not bool(pre_switch_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(pre_switch_snapshot_unwrap.get("error", "sukuna kamado pre-switch snapshot failed")))
	var pre_switch_target: Dictionary = _helper.find_unit_snapshot(pre_switch_snapshot_unwrap.get("data", {}), "P2", "P2-A")
	var hp_before_switch := int(pre_switch_target.get("current_hp", -1))
	if not _helper.unit_snapshot_has_effect(pre_switch_target, "sukuna_kamado_mark"):
		return harness.fail_result("sukuna manager kamado path should expose kamado mark before switch")
	var turn_two = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 2,
		"label": "run_turn(sukuna kamado)",
		"p1_action": "wait",
		"p2_action": "switch:P2-B",
		"p1_label": "build_command(sukuna kamado)",
		"p2_label": "build_command(sukuna kamado)",
	})
	if not bool(turn_two.get("ok", false)):
		return harness.fail_result(str(turn_two.get("error", "sukuna kamado turn2 failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(sukuna kamado)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "sukuna kamado snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var switched_target: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if int(switched_target.get("current_hp", -1)) >= hp_before_switch:
		return harness.fail_result("sukuna manager kamado on-exit path should reduce switched-out target HP")
	if _helper.unit_snapshot_has_effect(switched_target, "sukuna_kamado_mark"):
		return harness.fail_result("sukuna manager kamado on-exit path should clear kamado mark after switch")
	var active_target: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-B")
	if active_target.is_empty():
		return harness.fail_result("sukuna manager kamado on-exit path should expose switched-in target P2-B")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(sukuna kamado)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "sukuna kamado event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna manager kamado on-exit path event log must stay public-safe")
	var on_exit_damage_events := 0
	for event_snapshot in events:
		if String(event_snapshot.get("event_type", "")) != EventTypesScript.EFFECT_DAMAGE:
			continue
		if String(event_snapshot.get("trigger_name", "")) != "on_exit":
			continue
		if String(event_snapshot.get("target_public_id", "")) != "P2-A":
			continue
		on_exit_damage_events += 1
	if on_exit_damage_events != 1:
		return harness.fail_result("sukuna manager kamado on-exit path should expose exactly one public on_exit damage event")
	return harness.pass_result()

func _run_sukuna_manager_hatsu_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var session_id := String(state["session_id"])
	var before_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(sukuna hatsu before)")
	if not bool(before_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(before_snapshot_unwrap.get("error", "sukuna hatsu pre snapshot failed")))
	var before_target: Dictionary = _helper.find_unit_snapshot(before_snapshot_unwrap.get("data", {}), "P2", "P2-A")
	var target_hp_before := int(before_target.get("current_hp", -1))
	var turn_result = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn(sukuna kamado)",
		"p1_action": "sukuna_hatsu",
		"p2_action": "wait",
		"p1_label": "build_command(sukuna kamado)",
		"p2_label": "build_command(sukuna kamado)",
	})
	if not bool(turn_result.get("ok", false)):
		return harness.fail_result(str(turn_result.get("error", "sukuna hatsu run_turn failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(sukuna hatsu)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "sukuna hatsu snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if int(target_snapshot.get("current_hp", -1)) >= target_hp_before:
		return harness.fail_result("sukuna hatsu public path should damage the target")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(sukuna hatsu)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "sukuna hatsu event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna hatsu public path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "sukuna"):
		return harness.fail_result("sukuna hatsu public path should expose sukuna public action cast")
	return harness.pass_result()

func _run_sukuna_manager_teach_love_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var sample_factory = state["sample_factory"]
	var session_id := String(state["session_id"])
	var content_index = harness.build_loaded_content_index(sample_factory)
	var sukuna_definition = content_index.units.get("sukuna", null)
	var tidekit_definition = content_index.units.get("sample_tidekit", null)
	var gojo_definition = content_index.units.get("gojo_satoru", null)
	if sukuna_definition == null or tidekit_definition == null or gojo_definition == null:
		return harness.fail_result("sukuna teach love public path missing authored unit definitions")
	var sukuna_total := int(sukuna_definition.base_hp) + int(sukuna_definition.base_attack) + int(sukuna_definition.base_defense) + int(sukuna_definition.base_sp_attack) + int(sukuna_definition.base_sp_defense) + int(sukuna_definition.base_speed) + int(sukuna_definition.max_mp)
	var tidekit_total := int(tidekit_definition.base_hp) + int(tidekit_definition.base_attack) + int(tidekit_definition.base_defense) + int(tidekit_definition.base_sp_attack) + int(tidekit_definition.base_sp_defense) + int(tidekit_definition.base_speed) + int(tidekit_definition.max_mp)
	var gojo_total := int(gojo_definition.base_hp) + int(gojo_definition.base_attack) + int(gojo_definition.base_defense) + int(gojo_definition.base_sp_attack) + int(gojo_definition.base_sp_defense) + int(gojo_definition.base_speed) + int(gojo_definition.max_mp)
	var old_bonus := _support.resolve_matchup_gap_value(sukuna_total, tidekit_total, PackedInt32Array([20, 40, 70, 110, 160]), PackedInt32Array([9, 8, 7, 6, 5]), 0)
	var new_bonus := _support.resolve_matchup_gap_value(sukuna_total, gojo_total, PackedInt32Array([20, 40, 70, 110, 160]), PackedInt32Array([9, 8, 7, 6, 5]), 0)
	if old_bonus == new_bonus:
		return harness.fail_result("sukuna teach love public fixture should cross a matchup regen band after switch")
	var turn_one = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn(sukuna kamado)",
		"p1_action": "wait",
		"p2_action": "switch:P2-B",
		"p1_label": "build_command(sukuna kamado)",
		"p2_label": "build_command(sukuna kamado)",
	})
	if not bool(turn_one.get("ok", false)):
		return harness.fail_result(str(turn_one.get("error", "sukuna teach love turn1 failed")))
	var before_regen_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(sukuna teach love before regen)")
	if not bool(before_regen_unwrap.get("ok", false)):
		return harness.fail_result(str(before_regen_unwrap.get("error", "sukuna teach love pre-regen snapshot failed")))
	var before_regen_snapshot: Dictionary = before_regen_unwrap.get("data", {})
	var active_target: Dictionary = _helper.find_unit_snapshot(before_regen_snapshot, "P2", "P2-B")
	if active_target.is_empty() or not bool(active_target.get("is_active", false)):
		return harness.fail_result("sukuna teach love public path should expose switched-in target P2-B after matchup change")
	var before_regen_sukuna: Dictionary = _helper.find_unit_snapshot(before_regen_snapshot, "P1", "P1-A")
	var mp_before_regen := int(before_regen_sukuna.get("current_mp", -1))
	var turn_two = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 2,
		"label": "run_turn(sukuna kamado)",
		"p1_action": "wait",
		"p2_action": "wait",
		"p2_actor_public_id": "P2-B",
		"p1_label": "build_command(sukuna kamado)",
		"p2_label": "build_command(sukuna kamado)",
	})
	if not bool(turn_two.get("ok", false)):
		return harness.fail_result(str(turn_two.get("error", "sukuna teach love turn2 failed")))
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(sukuna teach love)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "sukuna teach love snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var sukuna_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	var delta_after_switch := int(sukuna_snapshot.get("current_mp", -1)) - mp_before_regen
	var expected_new_delta := int(sukuna_definition.regen_per_turn) + int(new_bonus)
	var expected_old_delta := int(sukuna_definition.regen_per_turn) + int(old_bonus)
	if delta_after_switch != expected_new_delta:
		return harness.fail_result("sukuna teach love public path should replace regen value after matchup change: expected=%d actual=%d" % [expected_new_delta, delta_after_switch])
	if delta_after_switch == expected_old_delta:
		return harness.fail_result("sukuna teach love public path should stop using the old matchup regen band after switch")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(sukuna teach love)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "sukuna teach love event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna teach love public path event log must stay public-safe")
	return harness.pass_result()
