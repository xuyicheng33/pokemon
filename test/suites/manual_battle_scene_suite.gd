extends GdUnitTestSuite

const BATTLE_SANDBOX_SCENE_PATH := "res://scenes/sandbox/BattleSandbox.tscn"

func test_manual_scene_initial_hud_stops_on_p1() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var state: Dictionary = controller.get_state_snapshot()
	assert_str(String(state.get("current_side_to_select", ""))).is_equal("P1")
	assert_bool(bool(controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/PrimaryButtons").get_child_count() > 0)).is_true()
	var status_label: Label = controller.get_node("RootMargin/MainColumn/HeaderPanel/HeaderContent/StatusLabel")
	var action_header_label: Label = controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ActionHeaderLabel")
	assert_str(status_label.text).contains("manual hotseat")
	assert_str(action_header_label.text).contains("当前待选边: P1")


func test_manual_scene_hotseat_round_trip_via_real_clicks() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var state_before: Dictionary = controller.get_state_snapshot()
	var turn_before := int(state_before.get("public_snapshot", {}).get("turn_index", 0))
	var cursor_before := int(state_before.get("event_log_cursor", 0))
	var p1_button := _find_clickable_action_button(controller, PackedStringArray(["奥义:", "技能:", "等待"]))
	assert_object(p1_button).is_not_null()
	await _click_button(runner, p1_button)
	var state_after_p1: Dictionary = controller.get_state_snapshot()
	assert_str(String(state_after_p1.get("current_side_to_select", ""))).is_equal("P2")
	assert_str(String(controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/PendingLabel").text)).contains("P1:")
	var p2_button := _find_clickable_action_button(controller, PackedStringArray(["奥义:", "技能:", "等待"]))
	assert_object(p2_button).is_not_null()
	await _click_button(runner, p2_button)
	var state_after_turn: Dictionary = controller.get_state_snapshot()
	var event_delta: Array = state_after_turn.get("last_event_delta", [])
	var recent_event_lines: Array = state_after_turn.get("recent_event_lines", [])
	var event_log_text: RichTextLabel = controller.get_node("RootMargin/MainColumn/BodyRow/EventPanel/EventContent/EventLogText")
	var rendered_event_log := event_log_text.get_parsed_text().strip_edges()
	assert_str(String(state_after_turn.get("current_side_to_select", ""))).is_equal("P1")
	assert_int(int(state_after_turn.get("public_snapshot", {}).get("turn_index", 0))).is_greater(turn_before)
	assert_int(int(state_after_turn.get("event_log_cursor", 0))).is_greater(cursor_before)
	assert_int(event_delta.size()).is_greater(0)
	assert_int(recent_event_lines.size()).is_greater(0)
	assert_str(rendered_event_log).is_not_empty()


func test_manual_scene_switch_wait_and_surrender_via_real_clicks() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var initial_snapshot: Dictionary = controller.get_state_snapshot().get("public_snapshot", {})
	var initial_active := _find_active_public_id(initial_snapshot, "P1")
	var switch_button := _find_clickable_action_button(controller, PackedStringArray(["换人:"]))
	assert_object(switch_button).is_not_null()
	var switch_target := String(switch_button.text).trim_prefix("换人: ").strip_edges()
	await _click_button(runner, switch_button)
	var p2_wait_button := _find_clickable_action_button(controller, PackedStringArray(["等待"]))
	assert_object(p2_wait_button).is_not_null()
	await _click_button(runner, p2_wait_button)
	var switched_snapshot: Dictionary = controller.get_state_snapshot().get("public_snapshot", {})
	var switched_active := _find_active_public_id(switched_snapshot, "P1")
	assert_str(switched_active).is_equal(switch_target)
	assert_str(switched_active).is_not_equal(initial_active)
	var surrender_button := _find_clickable_action_button(controller, PackedStringArray(["投降"]))
	assert_object(surrender_button).is_not_null()
	await _click_button(runner, surrender_button)
	var wait_button := _find_clickable_action_button(controller, PackedStringArray(["等待"]))
	assert_object(wait_button).is_not_null()
	await _click_button(runner, wait_button)
	var final_snapshot: Dictionary = controller.get_state_snapshot().get("public_snapshot", {})
	var battle_result = final_snapshot.get("battle_result", {})
	assert_bool(bool(battle_result.get("finished", false))).is_true()
	assert_str(String(battle_result.get("reason", ""))).is_equal("surrender")


func test_manual_scene_auto_battle_reaches_battle_result_via_real_clicks() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	for _index in range(80):
		var battle_result = controller.get_state_snapshot().get("public_snapshot", {}).get("battle_result", null)
		if battle_result is Dictionary and bool(battle_result.get("finished", false)):
			break
		var next_button := _find_clickable_action_button(controller, PackedStringArray(["奥义:", "技能:", "换人:", "等待"]))
		assert_object(next_button).is_not_null()
		await _click_button(runner, next_button)
	var final_state: Dictionary = controller.get_state_snapshot()
	var final_result = final_state.get("public_snapshot", {}).get("battle_result", {})
	assert_bool(bool(final_result.get("finished", false))).is_true()
	assert_int(int(final_state.get("event_log_cursor", 0))).is_greater(0)
	assert_str(String(final_result.get("result_type", ""))).is_not_empty()


func _create_runner() -> GdUnitSceneRunner:
	var runner := scene_runner(BATTLE_SANDBOX_SCENE_PATH)
	runner.set_time_factor(8.0)
	await await_millis(80)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	return runner


func _click_button(runner: GdUnitSceneRunner, button: Button) -> void:
	var center := button.get_global_rect().get_center()
	@warning_ignore("redundant_await")
	await runner.simulate_mouse_move_absolute(center, 0.02)
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	await await_millis(30)


func _find_clickable_action_button(controller: Node, prefixes: PackedStringArray) -> Button:
	var containers := [
		controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/PrimaryButtons"),
		controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/SwitchButtons"),
		controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/UtilityButtons"),
	]
	for raw_prefix in prefixes:
		var prefix := String(raw_prefix)
		for container in containers:
			for child in container.get_children():
				if child is Button and not child.disabled and child.visible and String(child.text).begins_with(prefix):
					return child
	return null


func _find_active_public_id(public_snapshot: Dictionary, side_id: String) -> String:
	for side_snapshot in public_snapshot.get("sides", []):
		if String(side_snapshot.get("side_id", "")) == side_id:
			return String(side_snapshot.get("active_public_id", ""))
	return ""
