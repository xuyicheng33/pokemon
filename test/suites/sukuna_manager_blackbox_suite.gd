extends "res://test/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")
const SukunaSetupRegenTestSupportScript := preload("res://tests/support/sukuna_setup_regen_test_support.gd")

var _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
var _helper = _smoke_helper.contracts()
var _support = SukunaSetupRegenTestSupportScript.new()



func test_sukuna_manager_kamado_on_exit_public_contract() -> void:
	_assert_legacy_result(_test_sukuna_manager_kamado_on_exit_public_contract(_harness))

func test_sukuna_manager_hatsu_public_contract() -> void:
	_assert_legacy_result(_test_sukuna_manager_hatsu_public_contract(_harness))

func test_sukuna_manager_teach_love_public_contract() -> void:
	_assert_legacy_result(_test_sukuna_manager_teach_love_public_contract(_harness))
func _test_sukuna_manager_kamado_on_exit_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "sukuna_setup")
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1331, battle_setup, "create_session(sukuna kamado)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "sukuna kamado create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var turn_one = _run_turn_result(manager, session_id, 1, "sukuna_hiraku", "wait")
	if not bool(turn_one.get("ok", false)):
		return harness.fail_result(str(turn_one.get("error", "sukuna kamado turn1 failed")))
	var pre_switch_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(sukuna kamado pre-switch)")
	if not bool(pre_switch_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(pre_switch_snapshot_unwrap.get("error", "sukuna kamado pre-switch snapshot failed")))
	var pre_switch_target: Dictionary = _helper.find_unit_snapshot(pre_switch_snapshot_unwrap.get("data", {}), "P2", "P2-A")
	var hp_before_switch := int(pre_switch_target.get("current_hp", -1))
	if not _helper.unit_snapshot_has_effect(pre_switch_target, "sukuna_kamado_mark"):
		return harness.fail_result("sukuna manager kamado path should expose kamado mark before switch")
	var turn_two = _run_turn_result(manager, session_id, 2, "wait", "switch:P2-B")
	if not bool(turn_two.get("ok", false)):
		return harness.fail_result(str(turn_two.get("error", "sukuna kamado turn2 failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(sukuna kamado)")
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
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(sukuna kamado)")
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
	_smoke_helper.close_session(manager, session_id, "close_session(sukuna kamado)")
	return harness.pass_result()

func _test_sukuna_manager_hatsu_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "sukuna_setup")
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1332, battle_setup, "create_session(sukuna hatsu)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "sukuna hatsu create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var before_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(sukuna hatsu before)")
	if not bool(before_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(before_snapshot_unwrap.get("error", "sukuna hatsu pre snapshot failed")))
	var before_target: Dictionary = _helper.find_unit_snapshot(before_snapshot_unwrap.get("data", {}), "P2", "P2-A")
	var target_hp_before := int(before_target.get("current_hp", -1))
	var turn_result = _run_turn_result(manager, session_id, 1, "sukuna_hatsu", "wait")
	if not bool(turn_result.get("ok", false)):
		return harness.fail_result(str(turn_result.get("error", "sukuna hatsu run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(sukuna hatsu)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "sukuna hatsu snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if int(target_snapshot.get("current_hp", -1)) >= target_hp_before:
		return harness.fail_result("sukuna hatsu public path should damage the target")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(sukuna hatsu)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "sukuna hatsu event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna hatsu public path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "sukuna"):
		return harness.fail_result("sukuna hatsu public path should expose sukuna public action cast")
	_smoke_helper.close_session(manager, session_id, "close_session(sukuna hatsu)")
	return harness.pass_result()

func _test_sukuna_manager_teach_love_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "sukuna_setup")
	battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_tidekit", "gojo_satoru", "sample_mossaur"])
	battle_setup.sides[1].starting_index = 0
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
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1333, battle_setup, "create_session(sukuna teach love)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "sukuna teach love create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var before_switch_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(sukuna teach love before switch)")
	if not bool(before_switch_unwrap.get("ok", false)):
		return harness.fail_result(str(before_switch_unwrap.get("error", "sukuna teach love pre-switch snapshot failed")))
	var before_switch: Dictionary = _helper.find_unit_snapshot(before_switch_unwrap.get("data", {}), "P1", "P1-A")
	var _mp_before_switch := int(before_switch.get("current_mp", -1))
	var turn_one = _run_turn_result(manager, session_id, 1, "wait", "switch:P2-B")
	if not bool(turn_one.get("ok", false)):
		return harness.fail_result(str(turn_one.get("error", "sukuna teach love turn1 failed")))
	var before_regen_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(sukuna teach love before regen)")
	if not bool(before_regen_unwrap.get("ok", false)):
		return harness.fail_result(str(before_regen_unwrap.get("error", "sukuna teach love pre-regen snapshot failed")))
	var before_regen_snapshot: Dictionary = before_regen_unwrap.get("data", {})
	var active_target: Dictionary = _helper.find_unit_snapshot(before_regen_snapshot, "P2", "P2-B")
	if active_target.is_empty() or not bool(active_target.get("is_active", false)):
		return harness.fail_result("sukuna teach love public path should expose switched-in target P2-B after matchup change")
	var before_regen_sukuna: Dictionary = _helper.find_unit_snapshot(before_regen_snapshot, "P1", "P1-A")
	var mp_before_regen := int(before_regen_sukuna.get("current_mp", -1))
	var turn_two = _run_turn_with_actor_ids_result(manager, session_id, 2, "P1-A", "wait", "P2-B", "wait")
	if not bool(turn_two.get("ok", false)):
		return harness.fail_result(str(turn_two.get("error", "sukuna teach love turn2 failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(sukuna teach love)")
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
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(sukuna teach love)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "sukuna teach love event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna teach love public path event log must stay public-safe")
	_smoke_helper.close_session(manager, session_id, "close_session(sukuna teach love)")
	return harness.pass_result()

func _run_turn_result(manager, session_id: String, turn_index: int, p1_action: String, p2_action: String) -> Dictionary:
	return _run_turn_with_actor_ids_result(manager, session_id, turn_index, "P1-A", p1_action, "P2-A", p2_action)

func _run_turn_with_actor_ids_result(
	manager,
	session_id: String,
	turn_index: int,
	p1_actor_public_id: String,
	p1_action: String,
	p2_actor_public_id: String,
	p2_action: String
) -> Dictionary:
	var p1_command = _build_command_result(manager, turn_index, "P1", p1_actor_public_id, p1_action)
	if not bool(p1_command.get("ok", false)):
		return p1_command
	var p2_command = _build_command_result(manager, turn_index, "P2", p2_actor_public_id, p2_action)
	if not bool(p2_command.get("ok", false)):
		return p2_command
	return _helper.unwrap_ok(manager.run_turn(session_id, [
		p1_command.get("data", null),
		p2_command.get("data", null),
	]), "run_turn(sukuna kamado)")

func _build_command_result(manager, turn_index: int, side_id: String, actor_public_id: String, action_spec: String) -> Dictionary:
	var command_payload := {
		"turn_index": turn_index,
		"command_source": "manual",
		"side_id": side_id,
		"actor_public_id": actor_public_id,
	}
	if action_spec == "wait":
		command_payload["command_type"] = CommandTypesScript.WAIT
	elif action_spec.begins_with("switch:"):
		command_payload["command_type"] = CommandTypesScript.SWITCH
		command_payload["target_public_id"] = String(action_spec.split(":", false, 1)[1]).strip_edges()
	else:
		command_payload["command_type"] = CommandTypesScript.SKILL
		command_payload["skill_id"] = action_spec
	return _helper.unwrap_ok(manager.build_command(command_payload), "build_command(sukuna kamado)")
