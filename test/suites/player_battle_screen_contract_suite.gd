extends "res://tests/support/gdunit_suite_bridge.gd"

const PlayerLogTextScript := preload("res://scenes/player/LogText.gd")
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
	var skill_button: Button = controller.get_node("MarginContainer/VBoxContainer/ActionBar/SkillButton_0")
	assert_bool(skill_button.visible).is_true()
	assert_bool(skill_button.disabled).is_false()
	skill_button.pressed.emit()
	await await_millis(120)
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	var snapshot_after: Dictionary = controller.get("_last_snapshot")
	var log_text: RichTextLabel = controller.get_node("MarginContainer/VBoxContainer/MiddleLog/ScrollContainer/LogText")
	var toast_container: CanvasLayer = controller.get_node("ErrorToastContainer")
	var rendered_log := log_text.get_parsed_text().strip_edges()
	assert_int(int(snapshot_after.get("turn_index", 0))).is_greater(turn_before)
	assert_str(rendered_log).is_not_empty()
	assert_str(rendered_log).contains("使用了")
	assert_str(rendered_log).not_contains("[action:cast]")
	assert_int(toast_container.get_child_count()).is_equal(0)
