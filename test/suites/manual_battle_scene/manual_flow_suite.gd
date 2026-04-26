extends "res://test/suites/manual_battle_scene/base.gd"
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _manifest = FormalCharacterManifestScript.new()

func test_manual_scene_starts_on_character_selection() -> void:
	var runner := await _create_selection_runner()
	var controller := runner.scene()
	assert_bool(controller.get_node("RootMargin/MainColumn/SelectPanel").visible).is_true()
	assert_bool(controller.get_node("RootMargin/MainColumn/BodyRow").visible).is_false()
	assert_bool(controller.get_node("RootMargin/MainColumn/ActionPanel").visible).is_false()
	var cards: GridContainer = controller.get_node("RootMargin/MainColumn/SelectPanel/SelectContent/CharacterScroll/CharacterCards")
	assert_int(cards.get_child_count()).is_equal(_visible_formal_setup_matchup_count(controller.get_state_snapshot().get("available_matchups", [])))
	var start_result: Dictionary = controller.start_player_matchup("gojo_vs_sample")
	assert_bool(bool(start_result.get("ok", false))).is_true()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	assert_bool(controller.get_node("RootMargin/MainColumn/SelectPanel").visible).is_false()
	assert_bool(controller.get_node("RootMargin/MainColumn/BodyRow").visible).is_true()
	assert_bool(controller.get_node("RootMargin/MainColumn/ActionPanel").visible).is_true()

func test_manual_scene_selection_grid_uses_desktop_columns() -> void:
	var runner := await _create_selection_runner()
	var controller := runner.scene()
	var cards: GridContainer = controller.get_node("RootMargin/MainColumn/SelectPanel/SelectContent/CharacterScroll/CharacterCards")
	controller.size = Vector2(1000, 720)
	controller.show_matchup_selection()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	assert_int(cards.columns).is_greater_equal(2)
	controller.size = Vector2(1280, 720)
	controller.show_matchup_selection()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	assert_int(cards.columns).is_greater_equal(4)

func _visible_formal_setup_matchup_count(available_matchups: Array) -> int:
	var available_ids: Dictionary = {}
	for raw_descriptor in _launch_config_helper.visible_matchup_descriptors(available_matchups):
		if not (raw_descriptor is Dictionary):
			continue
		var matchup_id := String(raw_descriptor.get("matchup_id", "")).strip_edges()
		if not matchup_id.is_empty():
			available_ids[matchup_id] = true
	var entries_result: Dictionary = _manifest.build_character_entries_result()
	assert_bool(bool(entries_result.get("ok", false))).is_true()
	var seen_matchup_ids: Dictionary = {}
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		var matchup_id := String(raw_entry.get("formal_setup_matchup_id", "")).strip_edges()
		if matchup_id.is_empty() or seen_matchup_ids.has(matchup_id) or not available_ids.has(matchup_id):
			continue
		seen_matchup_ids[matchup_id] = true
	return seen_matchup_ids.size()

func test_manual_scene_initial_hud_stops_on_p1() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var state: Dictionary = controller.get_state_snapshot()
	assert_str(String(state.get("current_side_to_select", ""))).is_equal("P1")
	assert_bool(bool(controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/PrimaryButtons").get_child_count() > 0)).is_true()
	var status_label: Label = controller.get_node("RootMargin/MainColumn/HeaderPanel/HeaderContent/StatusLabel")
	var action_header_label: Label = controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ActionHeaderLabel")
	assert_str(status_label.text).contains("config=manual/policy")
	assert_str(status_label.text).contains("policy=standby(P2)")
	assert_str(action_header_label.text).contains("当前待选边: P1")

func test_manual_scene_default_launch_config_contract() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var state: Dictionary = controller.get_state_snapshot()
	var launch_config: Dictionary = state.get("launch_config", {})
	var side_control_modes: Dictionary = state.get("side_control_modes", {})
	var available_matchups: Array = state.get("available_matchups", [])
	assert_str(String(launch_config.get("mode", ""))).is_equal("manual_matchup")
	assert_str(String(launch_config.get("matchup_id", ""))).is_equal("gojo_vs_sample")
	assert_int(int(launch_config.get("battle_seed", 0))).is_equal(9101)
	assert_str(String(side_control_modes.get("P1", ""))).is_equal("manual")
	assert_str(String(side_control_modes.get("P2", ""))).is_equal("policy")
	assert_bool(not _find_available_matchup(available_matchups, "gojo_vs_sample").is_empty()).is_true()

func test_manual_scene_hotseat_round_trip_via_real_clicks() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var restart_result: Dictionary = controller.restart_session_with_config({
		"matchup_id": "gojo_vs_sample",
		"battle_seed": 9201,
		"p1_control_mode": "manual",
		"p2_control_mode": "manual",
	})
	assert_bool(bool(restart_result.get("ok", false))).is_true()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
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

func test_manual_scene_policy_p2_auto_advances_turn_after_one_click() -> void:
	var runner := await _create_runner()
	var controller = runner.scene()
	var restart_result: Dictionary = controller.restart_session_with_config({
		"matchup_id": "gojo_vs_sample",
		"battle_seed": 9202,
		"p1_control_mode": "manual",
		"p2_control_mode": "policy",
	})
	assert_bool(bool(restart_result.get("ok", false))).is_true()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var state_before: Dictionary = controller.get_state_snapshot()
	var cursor_before := int(state_before.get("event_log_cursor", 0))
	var turn_before := int(state_before.get("public_snapshot", {}).get("turn_index", 0))
	var p1_button := _find_clickable_action_button(controller, PackedStringArray(["奥义:", "技能:", "等待"]))
	assert_object(p1_button).is_not_null()
	await _click_button(runner, p1_button)
	var state_after: Dictionary = controller.get_state_snapshot()
	assert_str(String(state_after.get("current_side_to_select", ""))).is_equal("P1")
	assert_int(int(state_after.get("public_snapshot", {}).get("turn_index", 0))).is_greater(turn_before)
	assert_int(int(state_after.get("event_log_cursor", 0))).is_greater(cursor_before)

func test_manual_scene_switch_wait_and_surrender_via_real_clicks() -> void:
	var runner := await _create_runner()
	var controller := runner.scene()
	var restart_result: Dictionary = controller.restart_session_with_config({
		"matchup_id": "gojo_vs_sample",
		"battle_seed": 9204,
		"p1_control_mode": "manual",
		"p2_control_mode": "manual",
	})
	assert_bool(bool(restart_result.get("ok", false))).is_true()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
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

func test_manual_scene_restart_with_matchup_and_seed_updates_state() -> void:
	var runner := await _create_runner()
	var controller = runner.scene()
	var initial_state: Dictionary = controller.get_state_snapshot()
	var initial_active_definition_id := _active_definition_id(initial_state, "P1")
	var restart_result: Dictionary = controller.restart_session_with_config({
		"matchup_id": "kashimo_vs_sample",
		"battle_seed": 9202,
		"p1_control_mode": "manual",
		"p2_control_mode": "manual",
	})
	assert_bool(bool(restart_result.get("ok", false))).is_true()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var restarted_state: Dictionary = controller.get_state_snapshot()
	var launch_config: Dictionary = restarted_state.get("launch_config", {})
	assert_str(String(launch_config.get("matchup_id", ""))).is_equal("kashimo_vs_sample")
	assert_int(int(launch_config.get("battle_seed", 0))).is_equal(9202)
	assert_str(String(restarted_state.get("current_side_to_select", ""))).is_equal("P1")
	assert_str(_active_definition_id(restarted_state, "P1")).is_not_equal(initial_active_definition_id)

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
	var battle_summary: Dictionary = final_state.get("battle_summary", {})
	assert_bool(bool(final_result.get("finished", false))).is_true()
	assert_int(int(final_state.get("event_log_cursor", 0))).is_greater(0)
	assert_str(String(final_result.get("result_type", ""))).is_not_empty()
	assert_str(String(battle_summary.get("matchup_id", ""))).is_equal("gojo_vs_sample")
	assert_int(int(battle_summary.get("battle_seed", 0))).is_equal(9101)
	assert_str(String(battle_summary.get("p1_control_mode", ""))).is_equal("manual")
	assert_str(String(battle_summary.get("p2_control_mode", ""))).is_equal("policy")
	assert_str(String(battle_summary.get("reason", ""))).is_not_empty()
	assert_int(int(battle_summary.get("event_log_cursor", 0))).is_greater(0)
	assert_int(int(battle_summary.get("command_steps", 0))).is_greater(0)

func test_manual_scene_policy_vs_policy_reaches_battle_result_and_summary() -> void:
	var runner := await _create_runner()
	var controller = runner.scene()
	var restart_result: Dictionary = controller.restart_session_with_config({
		"matchup_id": "gojo_vs_sample",
		"battle_seed": 9303,
		"p1_control_mode": "policy",
		"p2_control_mode": "policy",
	})
	assert_bool(bool(restart_result.get("ok", false))).is_true()
	for _index in range(20):
		var state_snapshot: Dictionary = controller.get_state_snapshot()
		var battle_result = state_snapshot.get("public_snapshot", {}).get("battle_result", {})
		if battle_result is Dictionary and bool(battle_result.get("finished", false)):
			break
		await await_millis(20)
		@warning_ignore("redundant_await")
		await runner.await_input_processed()
	var final_state: Dictionary = controller.get_state_snapshot()
	var final_result = final_state.get("public_snapshot", {}).get("battle_result", {})
	var battle_summary: Dictionary = final_state.get("battle_summary", {})
	assert_bool(bool(final_result.get("finished", false))).is_true()
	assert_str(String(battle_summary.get("matchup_id", ""))).is_equal("gojo_vs_sample")
	assert_int(int(battle_summary.get("battle_seed", 0))).is_equal(9303)
	assert_str(String(battle_summary.get("p1_control_mode", ""))).is_equal("policy")
	assert_str(String(battle_summary.get("p2_control_mode", ""))).is_equal("policy")
	assert_str(String(battle_summary.get("reason", ""))).is_not_empty()
	assert_int(int(battle_summary.get("turn_index", 0))).is_greater(0)
	assert_int(int(battle_summary.get("event_log_cursor", 0))).is_greater(0)
	assert_int(int(battle_summary.get("command_steps", 0))).is_greater(0)
