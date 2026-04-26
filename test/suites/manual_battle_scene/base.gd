extends "res://tests/support/gdunit_suite_bridge.gd"

const BATTLE_SANDBOX_SCENE_PATH := "res://scenes/sandbox/BattleSandbox.tscn"

func _create_runner() -> GdUnitSceneRunner:
	var runner := await _create_selection_runner()
	var controller = runner.scene()
	var start_result: Dictionary = controller.start_player_matchup("gojo_vs_sample")
	assert_bool(bool(start_result.get("ok", false))).is_true()
	@warning_ignore("redundant_await")
	await runner.await_input_processed()
	return runner

func _create_selection_runner() -> GdUnitSceneRunner:
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

func _find_control_button(controller: Node, button_name: String) -> Button:
	var controls: Node = controller.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons")
	for child in controls.get_children():
		if child is Button and String(child.text).strip_edges() == button_name:
			return child
		if child is HBoxContainer:
			for nested_child in child.get_children():
				if nested_child is Button and String(nested_child.text).strip_edges() == button_name:
					return nested_child
	return null

func _find_active_public_id(public_snapshot: Dictionary, side_id: String) -> String:
	for side_snapshot in public_snapshot.get("sides", []):
		if String(side_snapshot.get("side_id", "")) == side_id:
			return String(side_snapshot.get("active_public_id", ""))
	return ""

func _find_available_matchup(available_matchups: Array, matchup_id: String) -> Dictionary:
	for descriptor in available_matchups:
		if descriptor is Dictionary and String(descriptor.get("matchup_id", "")) == matchup_id:
			return descriptor
	return {}

func _active_definition_id(state_snapshot: Dictionary, side_id: String) -> String:
	var view_model: Dictionary = state_snapshot.get("view_model", {})
	for side_model in view_model.get("sides", []):
		if side_model is Dictionary and String(side_model.get("side_id", "")) == side_id:
			return String(side_model.get("active", {}).get("definition_id", ""))
	return ""

func _default_demo_profile_id(controller) -> String:
	var default_profile_result: Dictionary = controller.default_demo_profile_id_result()
	return String(default_profile_result.get("data", "")).strip_edges()
