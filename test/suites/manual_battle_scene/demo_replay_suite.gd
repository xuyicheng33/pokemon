extends "res://test/suites/manual_battle_scene/base.gd"
const BaseSuiteScript := preload("res://test/suites/manual_battle_scene/base.gd")

func test_demo_replay_scene_enters_turn_browser_contract() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var demo_profile_id := _default_demo_profile_id(controller)
	assert_str(demo_profile_id).is_not_empty()
	var restart_result: Dictionary = controller.restart_session_with_config({
		"mode": "demo_replay",
		"demo_profile_id": demo_profile_id,
	})
	assert_bool(bool(restart_result.get("ok", false))).is_true()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var state: Dictionary = controller.get_state_snapshot()
	var current_frame: Dictionary = state.get("replay_current_frame", {})
	var status_label: Label = controller.get_node("RootMargin/MainColumn/HeaderPanel/HeaderContent/StatusLabel")
	var action_header_label: Label = controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ActionHeaderLabel")
	var pending_label: Label = controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/PendingLabel")
	var event_header_label: Label = controller.get_node("RootMargin/MainColumn/BodyRow/EventPanel/EventContent/EventHeaderLabel")
	var prev_button := _find_control_button(controller, "上一回合")
	var next_button := _find_control_button(controller, "下一回合")
	assert_bool(bool(state.get("is_demo_mode", false))).is_true()
	assert_int(state.get("replay_turn_timeline", []).size()).is_greater(1)
	assert_int(int(state.get("replay_frame_index", -1))).is_equal(0)
	assert_int(int(current_frame.get("turn_index", -1))).is_equal(0)
	assert_int(int(state.get("event_log_cursor", -1))).is_equal(0)
	assert_str(status_label.text).contains("mode=read_only")
	assert_str(action_header_label.text).contains("回放浏览态")
	assert_str(pending_label.text).contains("只读回放")
	assert_str(event_header_label.text).contains("turn=0")
	assert_object(prev_button).is_not_null()
	assert_object(next_button).is_not_null()
	assert_bool(prev_button.disabled).is_true()
	assert_bool(next_button.disabled).is_false()

func test_demo_replay_scene_next_previous_switches_frame_contract() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var demo_profile_id := _default_demo_profile_id(controller)
	assert_str(demo_profile_id).is_not_empty()
	var restart_result: Dictionary = controller.restart_session_with_config({
		"mode": "demo_replay",
		"demo_profile_id": demo_profile_id,
	})
	assert_bool(bool(restart_result.get("ok", false))).is_true()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var prev_button := _find_control_button(controller, "上一回合")
	var next_button := _find_control_button(controller, "下一回合")
	assert_object(prev_button).is_not_null()
	assert_object(next_button).is_not_null()
	await _click_button(runner, next_button)
	var advanced_state: Dictionary = controller.get_state_snapshot()
	var advanced_frame: Dictionary = advanced_state.get("replay_current_frame", {})
	assert_int(int(advanced_state.get("replay_frame_index", -1))).is_equal(1)
	assert_int(int(advanced_frame.get("turn_index", 0))).is_equal(1)
	assert_int(int(advanced_state.get("event_log_cursor", 0))).is_greater(0)
	assert_int(int(advanced_frame.get("event_to", 0))).is_equal(int(advanced_state.get("event_log_cursor", -1)))
	assert_int(advanced_state.get("last_event_delta", []).size()).is_greater(0)
	assert_bool(prev_button.disabled).is_false()
	await _click_button(runner, prev_button)
	var rewound_state: Dictionary = controller.get_state_snapshot()
	assert_int(int(rewound_state.get("replay_frame_index", -1))).is_equal(0)
	assert_int(int(rewound_state.get("event_log_cursor", -1))).is_equal(0)
	assert_int(int(rewound_state.get("replay_current_frame", {}).get("turn_index", -1))).is_equal(0)

func test_demo_replay_scene_blocks_manual_actions_contract() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var demo_profile_id := _default_demo_profile_id(controller)
	assert_str(demo_profile_id).is_not_empty()
	var restart_result: Dictionary = controller.restart_session_with_config({
		"mode": "demo_replay",
		"demo_profile_id": demo_profile_id,
	})
	assert_bool(bool(restart_result.get("ok", false))).is_true()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	assert_object(_find_clickable_action_button(controller, PackedStringArray(["技能:", "奥义:", "等待", "投降", "换人:"]))).is_null()
	var submit_result: Dictionary = controller.submit_action({"command_type": "wait"})
	assert_bool(bool(submit_result.get("ok", true))).is_false()
	assert_str(String(submit_result.get("error", ""))).contains("demo mode does not accept manual actions")
