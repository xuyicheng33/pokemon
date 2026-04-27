extends "res://tests/support/gdunit_suite_bridge.gd"

const PlayerLogTextScript := preload("res://scenes/player/LogText.gd")
const ForcedReplaceDialogScene := preload("res://scenes/player/ForcedReplaceDialog.tscn")
const BATTLE_SCREEN_SCENE_PATH := "res://scenes/player/BattleScreen.tscn"


func test_player_log_text_formats_public_event_snapshot_fields() -> void:
	var log_text: PlayerLogText = PlayerLogTextScript.new()
	log_text._ready()
	log_text.append_event({
		"event_type": "action:cast",
		"turn_index": 1,
		"actor_public_id": "gojo#P1A",
		"command_type": "skill",
		"payload_summary": "skill cast",
	})
	log_text.append_event({
		"event_type": "effect:damage",
		"turn_index": 1,
		"target_public_id": "sample#P2A",
		"value_changes": [{
			"entity_public_id": "sample#P2A",
			"resource_name": "hp",
			"before_value": 100,
			"after_value": 83,
			"delta": -17,
		}],
		"payload_summary": "gojo#P1A dealt 17 damage to sample#P2A",
	})
	log_text.append_event({
		"event_type": "action:miss",
		"turn_index": 1,
		"actor_public_id": "gojo#P1A",
		"target_public_id": "sample#P2A",
		"payload_summary": "skill missed",
	})
	var rendered := log_text.get_parsed_text()
	assert_str(rendered).contains("gojo#P1A 使用了 技能")
	assert_str(rendered).contains("sample#P2A 受到 17 点伤害")
	assert_str(rendered).contains("未命中")
	assert_str(rendered).not_contains("[action:cast]")
	assert_str(rendered).not_contains("[action:miss]")
	log_text.free()


func test_player_battle_screen_skill_button_signal_advances_turn_and_renders_log() -> void:
	var runner := scene_runner(BATTLE_SCREEN_SCENE_PATH)
	runner.set_time_factor(8.0)
	await await_millis(120)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var controller: PlayerBattleScreen = runner.scene()
	var snapshot_before: Dictionary = controller.get("_last_snapshot")
	var turn_before := int(snapshot_before.get("turn_index", 0))
	var skill_button: Button = controller.get_node("MainScroll/MarginContainer/VBoxContainer/ActionBar/SkillButton_0")
	assert_bool(skill_button.visible).is_true()
	assert_bool(skill_button.disabled).is_false()
	skill_button.pressed.emit()
	await await_millis(120)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var snapshot_after: Dictionary = controller.get("_last_snapshot")
	var log_text: RichTextLabel = controller.get_node("MainScroll/MarginContainer/VBoxContainer/MiddleLog/ScrollContainer/LogText")
	var toast_container: CanvasLayer = controller.get_node("ErrorToastContainer")
	var rendered_log := log_text.get_parsed_text().strip_edges()
	assert_int(int(snapshot_after.get("turn_index", 0))).is_greater(turn_before)
	assert_str(rendered_log).is_not_empty()
	assert_str(rendered_log).contains("使用了")
	assert_str(rendered_log).not_contains("[action:cast]")
	assert_int(toast_container.get_child_count()).is_equal(0)


func test_player_battle_screen_uses_scroll_shell_for_small_viewports() -> void:
	var runner := scene_runner(BATTLE_SCREEN_SCENE_PATH)
	runner.set_time_factor(8.0)
	await await_millis(120)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var controller: PlayerBattleScreen = runner.scene()
	controller.size = Vector2(960, 540)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var main_scroll: ScrollContainer = controller.get_node("MainScroll")
	var action_bar: GridContainer = controller.get_node("MainScroll/MarginContainer/VBoxContainer/ActionBar")
	assert_int(int(controller.custom_minimum_size.x)).is_less_equal(960)
	assert_int(int(controller.custom_minimum_size.y)).is_less_equal(540)
	assert_bool(main_scroll.visible).is_true()
	assert_bool(action_bar.visible).is_true()


func test_player_battle_screen_matchup_select_lists_visible_matchups() -> void:
	var runner := scene_runner(BATTLE_SCREEN_SCENE_PATH)
	runner.set_time_factor(8.0)
	await await_millis(120)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var controller: PlayerBattleScreen = runner.scene()
	var matchup_select: OptionButton = controller.get_node("MainScroll/MarginContainer/VBoxContainer/TopBar/MatchupSelect")
	assert_int(matchup_select.item_count).is_greater_equal(4)
	var matchup_ids: Array = []
	for i in matchup_select.item_count:
		matchup_ids.append(String(matchup_select.get_item_metadata(i)))
	for expected_matchup_id in ["gojo_vs_sample", "sukuna_setup", "kashimo_vs_sample", "obito_vs_sample"]:
		if not matchup_ids.has(expected_matchup_id):
			fail("player matchup select missing visible matchup: %s from %s" % [expected_matchup_id, matchup_ids])
			return
	assert_str(String(matchup_select.get_item_metadata(matchup_select.selected))).is_equal("gojo_vs_sample")
	assert_str(String(controller.get("_current_matchup_id"))).is_equal("gojo_vs_sample")


func test_player_battle_screen_start_button_switches_selected_matchup() -> void:
	var runner := scene_runner(BATTLE_SCREEN_SCENE_PATH)
	runner.set_time_factor(8.0)
	await await_millis(120)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var controller: PlayerBattleScreen = runner.scene()
	var matchup_select: OptionButton = controller.get_node("MainScroll/MarginContainer/VBoxContainer/TopBar/MatchupSelect")
	var target_index := _find_matchup_option_index(matchup_select, "kashimo_vs_sample")
	assert_int(target_index).is_greater_equal(0)
	matchup_select.select(target_index)
	var start_button: Button = controller.get_node("MainScroll/MarginContainer/VBoxContainer/TopBar/StartMatchupButton")
	assert_bool(start_button.disabled).is_false()
	start_button.pressed.emit()
	await await_millis(160)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var snapshot_after: Dictionary = controller.get("_last_snapshot")
	var toast_container: CanvasLayer = controller.get_node("ErrorToastContainer")
	assert_str(String(controller.get("_current_matchup_id"))).is_equal("kashimo_vs_sample")
	assert_str(_active_unit_definition_id(snapshot_after, "P1")).is_equal("kashimo_hajime")
	assert_int(int(snapshot_after.get("turn_index", 0))).is_equal(1)
	assert_int(toast_container.get_child_count()).is_equal(0)


func test_player_battle_screen_wait_button_signal_advances_turn() -> void:
	var runner := scene_runner(BATTLE_SCREEN_SCENE_PATH)
	runner.set_time_factor(8.0)
	await await_millis(120)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var controller: PlayerBattleScreen = runner.scene()
	var snapshot_before: Dictionary = controller.get("_last_snapshot")
	var turn_before := int(snapshot_before.get("turn_index", 0))
	var wait_button: Button = controller.get_node("MainScroll/MarginContainer/VBoxContainer/ActionBar/WaitButton")
	# 先锁住 fixture 前提：默认 gojo_vs_sample 首回合 wait 必须可点；
	# 失败时明确指向 fixture / legality 漂移，而不是按钮信号坏了。
	assert_bool(wait_button.visible).is_true()
	assert_bool(wait_button.disabled).is_false()
	wait_button.pressed.emit()
	await await_millis(120)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var snapshot_after: Dictionary = controller.get("_last_snapshot")
	var toast_container: CanvasLayer = controller.get_node("ErrorToastContainer")
	assert_int(int(snapshot_after.get("turn_index", 0))).is_greater(turn_before)
	assert_int(toast_container.get_child_count()).is_equal(0)


func test_player_battle_screen_switch_menu_button_pops_menu_with_options() -> void:
	var runner := scene_runner(BATTLE_SCREEN_SCENE_PATH)
	runner.set_time_factor(8.0)
	await await_millis(120)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var controller: PlayerBattleScreen = runner.scene()
	var legal: Dictionary = controller.call("_local_legal_action_summary")
	var legal_switch_ids: Array = legal.get("legal_switch_target_public_ids", [])
	# 锁住 fixture 前提：默认局首回合至少有 1 个合法换人目标，否则按钮就该是 disabled。
	assert_int(legal_switch_ids.size()).is_greater(0)
	var switch_button: Button = controller.get_node("MainScroll/MarginContainer/VBoxContainer/ActionBar/SwitchMenuButton")
	assert_bool(switch_button.visible).is_true()
	assert_bool(switch_button.disabled).is_false()
	switch_button.pressed.emit()
	# PopupMenu.popup() 之后等一帧再读 visible / item count，否则在 headless 下可能拿到旧状态。
	await await_millis(60)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var popup: PopupMenu = controller.get("_switch_menu_popup")
	var options: Array = controller.get("_switch_menu_options")
	assert_object(popup).is_not_null()
	assert_int(popup.get_item_count()).is_equal(legal_switch_ids.size())
	assert_int(options.size()).is_equal(legal_switch_ids.size())
	for i in legal_switch_ids.size():
		assert_str(String(options[i])).is_equal(String(legal_switch_ids[i]))


func test_player_forced_replace_dialog_invokes_callback_with_selected_id() -> void:
	# 不构造完整 KO 局；直接 instantiate dialog，验证 open / 点击 / callback / close 的最小 contract。
	var dialog: PlayerForcedReplaceDialog = ForcedReplaceDialogScene.instantiate()
	add_child(dialog)
	await await_idle_frame()
	var legal_ids: Array = ["sukuna#1", "kashimo#1"]
	var captured := {"value": ""}
	var on_select := func(public_id: String) -> void:
		captured["value"] = public_id
	dialog.open(legal_ids, on_select)
	await await_idle_frame()
	assert_bool(dialog.visible).is_true()
	# 用户建议 3：递归找 dialog 内 Button，避免硬编码 Center/Panel/VBox/ListContainer 路径。
	var buttons: Array = dialog.find_children("*", "Button", true, false)
	assert_int(buttons.size()).is_equal(legal_ids.size())
	# 点第二个，检测 callback 拿到的是对应 public_id 而不是首项。
	var second_button: Button = buttons[1]
	second_button.pressed.emit()
	await await_idle_frame()
	assert_str(String(captured["value"])).is_equal(String(legal_ids[1]))
	# 点击后必须自动 close。
	assert_bool(dialog.visible).is_false()
	dialog.queue_free()


func _find_matchup_option_index(matchup_select: OptionButton, matchup_id: String) -> int:
	for i in matchup_select.item_count:
		if String(matchup_select.get_item_metadata(i)) == matchup_id:
			return i
	return -1


func _active_unit_definition_id(snapshot: Dictionary, side_id: String) -> String:
	for raw_side in snapshot.get("sides", []):
		if not (raw_side is Dictionary):
			continue
		var side: Dictionary = raw_side
		if String(side.get("side_id", "")) != side_id:
			continue
		var active_public_id := String(side.get("active_public_id", "")).strip_edges()
		for raw_unit in side.get("team_units", []):
			if not (raw_unit is Dictionary):
				continue
			var unit: Dictionary = raw_unit
			if String(unit.get("public_id", "")).strip_edges() == active_public_id:
				return String(unit.get("definition_id", "")).strip_edges()
	return ""
