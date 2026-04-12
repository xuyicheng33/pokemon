extends RefCounted
class_name ManualBattleSceneSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")
const ManualBattleSceneSupportScript := preload("res://tests/support/manual_battle_scene_support.gd")

var _helper = ManagerContractTestHelperScript.new()
var _support = ManualBattleSceneSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("manual_scene_fixed_session_bootstrap", failures, Callable(self, "_test_manual_scene_fixed_session_bootstrap").bind(harness))
	runner.run_test("manual_scene_initial_public_snapshot_renderable", failures, Callable(self, "_test_manual_scene_initial_public_snapshot_renderable").bind(harness))
	runner.run_test("manual_scene_hud_node_graph_smoke", failures, Callable(self, "_test_manual_scene_hud_node_graph_smoke").bind(harness))
	runner.run_test("manual_scene_hotseat_round_trip_and_event_log_cursor", failures, Callable(self, "_test_manual_scene_hotseat_round_trip_and_event_log_cursor").bind(harness))
	runner.run_test("manual_scene_switch_wait_and_surrender_to_battle_result", failures, Callable(self, "_test_manual_scene_switch_wait_and_surrender_to_battle_result").bind(harness))
	runner.run_test("manual_scene_auto_battle_reaches_battle_result", failures, Callable(self, "_test_manual_scene_auto_battle_reaches_battle_result").bind(harness))

func _test_manual_scene_fixed_session_bootstrap(harness) -> Dictionary:
	var context_result = _support.build_manual_scene_context(harness, 9101)
	if not bool(context_result.get("ok", false)):
		return harness.fail_result(str(context_result.get("error", "manual scene context bootstrap failed")))
	var context: Dictionary = context_result
	var public_snapshot: Dictionary = context.get("public_snapshot", {})
	var shape_error: String = _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return _fail_with_context_close(harness, context, "fixed session bootstrap snapshot malformed: %s" % shape_error)
	if String(context.get("session_id", "")).is_empty():
		return _fail_with_context_close(harness, context, "fixed session bootstrap should return non-empty session_id")
	return _pass_with_context_close(harness, context)

func _test_manual_scene_initial_public_snapshot_renderable(harness) -> Dictionary:
	var context_result = _support.build_manual_scene_context(harness, 9102)
	if not bool(context_result.get("ok", false)):
		return harness.fail_result(str(context_result.get("error", "manual scene context bootstrap failed")))
	var context: Dictionary = context_result
	var view_model: Dictionary = _support.build_view_model(context)
	var render_error: String = _support.validate_view_model_renderable(view_model)
	if not render_error.is_empty():
		return _fail_with_context_close(harness, context, "initial public_snapshot should be renderable: %s" % render_error)
	if not view_model.has("battle_result"):
		return _fail_with_context_close(harness, context, "view_model should keep battle_result key for UI rendering")
	if String(context.get("current_side_to_select", "")) != "P1":
		return _fail_with_context_close(harness, context, "manual scene should stop on P1 selection after bootstrap")
	return _pass_with_context_close(harness, context)

func _test_manual_scene_hud_node_graph_smoke(harness) -> Dictionary:
	var context_result = _support.build_manual_scene_context(harness, 9105)
	if not bool(context_result.get("ok", false)):
		return harness.fail_result(str(context_result.get("error", "manual scene context bootstrap failed")))
	var context: Dictionary = context_result
	var controller = context.get("controller", null)
	if controller == null:
		return _fail_with_context_close(harness, context, "manual scene HUD smoke should expose controller")
	var status_label = controller.get_node_or_null("RootMargin/MainColumn/HeaderPanel/HeaderContent/StatusLabel")
	if status_label == null:
		return _fail_with_context_close(harness, context, "manual scene HUD missing StatusLabel")
	var action_header_label = controller.get_node_or_null("RootMargin/MainColumn/ActionPanel/ActionContent/ActionHeaderLabel")
	if action_header_label == null:
		return _fail_with_context_close(harness, context, "manual scene HUD missing ActionHeaderLabel")
	var primary_buttons = controller.get_node_or_null("RootMargin/MainColumn/ActionPanel/ActionContent/PrimaryButtons")
	var utility_buttons = controller.get_node_or_null("RootMargin/MainColumn/ActionPanel/ActionContent/UtilityButtons")
	if primary_buttons == null or utility_buttons == null:
		return _fail_with_context_close(harness, context, "manual scene HUD missing action button containers")
	var view_model: Dictionary = _support.build_view_model(context)
	var status_text := String(controller._format_status_text(view_model))
	var action_header_text := String(controller._format_action_header(view_model))
	if status_text.find("manual hotseat") == -1:
		return _fail_with_context_close(harness, context, "manual scene status formatter should include manual hotseat mode")
	if action_header_text.find("当前待选边: P1") == -1:
		return _fail_with_context_close(harness, context, "manual scene action header formatter should point to P1 on first selection")
	if primary_buttons.get_child_count() != 0 or utility_buttons.get_child_count() != 0:
		return _fail_with_context_close(harness, context, "detached manual scene should not mutate button containers before UI render")
	return _pass_with_context_close(harness, context)

func _test_manual_scene_hotseat_round_trip_and_event_log_cursor(harness) -> Dictionary:
	var context_result = _support.build_manual_scene_context(harness, 9103)
	if not bool(context_result.get("ok", false)):
		return harness.fail_result(str(context_result.get("error", "manual scene context bootstrap failed")))
	var context: Dictionary = context_result
	var cursor_before := int(context.get("event_log_cursor", 0))
	var p1_legal_unwrap = _support.get_legal_actions(context, "P1")
	if not bool(p1_legal_unwrap.get("ok", false)):
		return _fail_with_context_close(harness, context, str(p1_legal_unwrap.get("error", "get_legal_actions(P1) failed")))
	var p1_legal = p1_legal_unwrap.get("data", null)
	if p1_legal == null:
		return _fail_with_context_close(harness, context, "hotseat round trip requires initial P1 legal actions")
	var p1_action := _pick_action_for_round_trip(p1_legal)
	var p1_submit_result = context.get("controller", null).submit_selected_action(p1_action)
	if not bool(p1_submit_result.get("ok", false)):
		return _fail_with_context_close(harness, context, str(p1_submit_result.get("error", "submit_selected_action(P1) failed")))
	var p2_state: Dictionary = context.get("controller", null).get_state_snapshot()
	context["public_snapshot"] = p2_state.get("public_snapshot", {})
	context["event_log_cursor"] = int(p2_state.get("event_log_cursor", cursor_before))
	context["legal_actions_by_side"] = p2_state.get("legal_actions_by_side", {})
	context["pending_commands"] = p2_state.get("pending_commands", {})
	context["current_side_to_select"] = p2_state.get("current_side_to_select", "")
	context["view_model"] = p2_state.get("view_model", {})
	if String(context.get("current_side_to_select", "")) != "P2":
		return _fail_with_context_close(harness, context, "after P1 locks command, manual scene should switch to P2")
	if not context.get("pending_commands", {}).has("P1"):
		return _fail_with_context_close(harness, context, "P1 command should be cached before P2 selection")
	var p2_legal_unwrap = _support.get_legal_actions(context, "P2")
	if not bool(p2_legal_unwrap.get("ok", false)):
		return _fail_with_context_close(harness, context, str(p2_legal_unwrap.get("error", "get_legal_actions(P2) failed")))
	var p2_legal = p2_legal_unwrap.get("data", null)
	if p2_legal == null:
		return _fail_with_context_close(harness, context, "hotseat round trip requires P2 legal actions after P1 selection")
	var p2_action := _pick_action_for_round_trip(p2_legal)
	var turn_before := _support.current_turn_index(context)
	var p2_submit_result = context.get("controller", null).submit_selected_action(p2_action)
	if not bool(p2_submit_result.get("ok", false)):
		return _fail_with_context_close(harness, context, str(p2_submit_result.get("error", "submit_selected_action(P2) failed")))
	var state_after_turn: Dictionary = context.get("controller", null).get_state_snapshot()
	context["public_snapshot"] = state_after_turn.get("public_snapshot", {})
	context["event_log_cursor"] = int(state_after_turn.get("event_log_cursor", cursor_before))
	context["legal_actions_by_side"] = state_after_turn.get("legal_actions_by_side", {})
	context["pending_commands"] = state_after_turn.get("pending_commands", {})
	context["current_side_to_select"] = state_after_turn.get("current_side_to_select", "")
	context["view_model"] = state_after_turn.get("view_model", {})
	context["last_event_delta"] = state_after_turn.get("last_event_delta", [])
	var run_result := {
		"ok": true,
		"event_delta": context.get("last_event_delta", []),
	}
	if not bool(run_result.get("ok", false)):
		return _fail_with_context_close(harness, context, str(run_result.get("error", "run_hotseat_turn failed")))
	var delta_events: Array = run_result.get("event_delta", [])
	if delta_events.is_empty():
		return _fail_with_context_close(harness, context, "event_log delta should not be empty after one hotseat turn")
	var turn_after := _support.current_turn_index(context)
	if turn_after <= turn_before:
		return _fail_with_context_close(harness, context, "hotseat round should advance turn index")
	var cursor_after := int(context.get("event_log_cursor", cursor_before))
	if cursor_after <= cursor_before:
		return _fail_with_context_close(harness, context, "event_log cursor should increase after run_turn")
	var manager = context.get("manager", null)
	var session_id := String(context.get("session_id", ""))
	var tail_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id, cursor_after), "get_event_log_snapshot(tail)")
	if not bool(tail_unwrap.get("ok", false)):
		return _fail_with_context_close(harness, context, str(tail_unwrap.get("error", "manager get_event_log_snapshot tail failed")))
	if not tail_unwrap.get("data", {}).get("events", []).is_empty():
		return _fail_with_context_close(harness, context, "event_log tail query should return empty events after cursor catches up")
	return _pass_with_context_close(harness, context)

func _test_manual_scene_switch_wait_and_surrender_to_battle_result(harness) -> Dictionary:
	var context_result = _support.build_manual_scene_context(harness, 9104)
	if not bool(context_result.get("ok", false)):
		return harness.fail_result(str(context_result.get("error", "manual scene context bootstrap failed")))
	var context: Dictionary = context_result
	var p1_legal_unwrap = _support.get_legal_actions(context, "P1")
	if not bool(p1_legal_unwrap.get("ok", false)):
		return _fail_with_context_close(harness, context, str(p1_legal_unwrap.get("error", "get_legal_actions(P1) failed")))
	var p1_legal = p1_legal_unwrap.get("data", null)
	if p1_legal == null:
		return _fail_with_context_close(harness, context, "missing P1 legal actions for switch scenario")
	if p1_legal.legal_switch_target_public_ids.is_empty():
		return _fail_with_context_close(harness, context, "fixed setup should expose at least one switch target for P1")
	var switch_target := String(p1_legal.legal_switch_target_public_ids[0])
	var switch_turn_result = _support.run_hotseat_turn(context, {
		"command_type": CommandTypesScript.SWITCH,
		"target_public_id": switch_target,
	}, {
		"command_type": CommandTypesScript.WAIT,
	})
	if not bool(switch_turn_result.get("ok", false)):
		return _fail_with_context_close(harness, context, str(switch_turn_result.get("error", "switch/wait hotseat turn failed")))
	var snapshot_after_switch: Dictionary = context.get("public_snapshot", {})
	var p1_side_after_switch := _helper.find_side_snapshot(snapshot_after_switch, "P1")
	if p1_side_after_switch.is_empty():
		return _fail_with_context_close(harness, context, "snapshot after switch missing P1 side")
	if String(p1_side_after_switch.get("active_public_id", "")) != switch_target:
		return _fail_with_context_close(harness, context, "switch should update P1 active_public_id to selected target")
	var surrender_turn_result = _support.run_hotseat_turn(
		context,
		{
			"command_type": CommandTypesScript.SURRENDER,
		},
		{
			"command_type": CommandTypesScript.WAIT,
		}
	)
	if not bool(surrender_turn_result.get("ok", false)):
		return _fail_with_context_close(harness, context, str(surrender_turn_result.get("error", "surrender hotseat turn failed")))
	var final_snapshot: Dictionary = context.get("public_snapshot", {})
	var battle_result = final_snapshot.get("battle_result", null)
	if typeof(battle_result) != TYPE_DICTIONARY:
		return _fail_with_context_close(harness, context, "battle_result should be non-null after surrender")
	if not bool(battle_result.get("finished", false)):
		return _fail_with_context_close(harness, context, "battle_result.finished should be true after surrender")
	if String(battle_result.get("reason", "")) != "surrender":
		return _fail_with_context_close(harness, context, "battle_result.reason should be surrender after surrender command")
	var surrender_logged := false
	for event_snapshot in surrender_turn_result.get("event_delta", []):
		if String(event_snapshot.get("event_type", "")) == "result:battle_end" \
		and String(event_snapshot.get("payload_summary", "")).find("surrender") != -1:
			surrender_logged = true
			break
	if not surrender_logged:
		return _fail_with_context_close(harness, context, "event log delta should include surrender battle_end event")
	return _pass_with_context_close(harness, context)

func _test_manual_scene_auto_battle_reaches_battle_result(harness) -> Dictionary:
	var context_result = _support.build_manual_scene_context(harness, 9106)
	if not bool(context_result.get("ok", false)):
		return harness.fail_result(str(context_result.get("error", "manual scene context bootstrap failed")))
	var context: Dictionary = context_result
	var auto_result = _support.run_to_battle_end(context, 64)
	if not bool(auto_result.get("ok", false)):
		return _fail_with_context_close(harness, context, str(auto_result.get("error", "manual scene auto battle failed")))
	var battle_result = auto_result.get("battle_result", null)
	if typeof(battle_result) != TYPE_DICTIONARY:
		return _fail_with_context_close(harness, context, "auto battle should finish with battle_result dictionary")
	if not bool(battle_result.get("finished", false)):
		return _fail_with_context_close(harness, context, "auto battle should mark battle_result.finished=true")
	var result_type := String(battle_result.get("result_type", ""))
	var reason := String(battle_result.get("reason", ""))
	if result_type.is_empty() or reason.is_empty():
		return _fail_with_context_close(harness, context, "auto battle should produce non-empty result_type and reason")
	var winner_side_id = battle_result.get("winner_side_id", null)
	if result_type == "win" and winner_side_id == null:
		return _fail_with_context_close(harness, context, "win result should expose winner_side_id")
	if (result_type == "draw" or result_type == "no_winner") and winner_side_id != null:
		return _fail_with_context_close(harness, context, "draw/no_winner result should not expose winner_side_id")
	if int(auto_result.get("event_log_cursor", 0)) <= 0:
		return _fail_with_context_close(harness, context, "auto battle should advance event_log_cursor")
	return _pass_with_context_close(harness, context)

func _pick_action_for_round_trip(legal_actions) -> Dictionary:
	if legal_actions == null:
		return {"command_type": CommandTypesScript.WAIT}
	if legal_actions.legal_skill_ids.size() > 0:
		return {
			"command_type": CommandTypesScript.SKILL,
			"skill_id": String(legal_actions.legal_skill_ids[0]),
		}
	if legal_actions.wait_allowed:
		return {"command_type": CommandTypesScript.WAIT}
	if legal_actions.legal_switch_target_public_ids.size() > 0:
		return {
			"command_type": CommandTypesScript.SWITCH,
			"target_public_id": String(legal_actions.legal_switch_target_public_ids[0]),
		}
	if legal_actions.legal_ultimate_ids.size() > 0:
		return {
			"command_type": CommandTypesScript.ULTIMATE,
			"skill_id": String(legal_actions.legal_ultimate_ids[0]),
		}
	return {"command_type": CommandTypesScript.SURRENDER}

func _pass_with_context_close(harness, context: Dictionary) -> Dictionary:
	var close_result = _support.close_context(context)
	if not bool(close_result.get("ok", false)):
		return harness.fail_result(str(close_result.get("error", "manager close_session failed")))
	return harness.pass_result()

func _fail_with_context_close(harness, context: Dictionary, message: String) -> Dictionary:
	var close_result = _support.close_context(context)
	if not bool(close_result.get("ok", false)):
		return harness.fail_result("%s; close_session failed: %s" % [message, str(close_result.get("error", "unknown error"))])
	return harness.fail_result(message)
