extends RefCounted
class_name SandboxViewActionButtonsRenderer

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormatHelperScript := preload("res://src/adapters/sandbox_view_format_helper.gd")
const PaletteScript := preload("res://src/adapters/sandbox_view_palette.gd")

var _fmt = FormatHelperScript.new()

func render(controller, state: SandboxSessionState, view_refs: SandboxViewRefs, current_view_model: Dictionary, current_player_ui_mode: String) -> void:
	_clear_container_children(view_refs.primary_buttons)
	_clear_container_children(view_refs.switch_buttons)
	_clear_container_children(view_refs.utility_buttons)
	view_refs.switch_label.visible = false
	if state.startup_failed:
		return
	if current_player_ui_mode == "select":
		_add_info_button(view_refs.primary_buttons, "选择角色后进入战斗")
		return
	if state.is_demo_mode:
		_add_info_button(view_refs.primary_buttons, "只读回放：使用上一回合/下一回合浏览")
		return
	if _fmt.has_battle_result(state.public_snapshot):
		_add_info_button(view_refs.primary_buttons, "对局已结束，可按当前配置重开")
		return
	var side_id = str(current_view_model.get("current_side_to_select", "")).strip_edges()
	if side_id.is_empty():
		_add_info_button(view_refs.primary_buttons, "等待下一步状态同步")
		return
	if _fmt.is_policy_side(state.side_control_modes, side_id):
		_add_info_button(view_refs.primary_buttons, "%s 当前由 policy 控制" % side_id)
		return
	var legal_actions: Dictionary = current_view_model.get("legal_actions_by_side", {}).get(side_id, {})
	if legal_actions.is_empty():
		_add_info_button(view_refs.primary_buttons, "当前边缺少合法动作")
		return
	for skill_id in legal_actions.get("legal_skill_ids", []):
		_add_action_button(controller, view_refs.primary_buttons, "技能: %s" % str(skill_id), {
			"command_type": CommandTypesScript.SKILL,
			"skill_id": str(skill_id),
		})
	for ultimate_id in legal_actions.get("legal_ultimate_ids", []):
		_add_action_button(controller, view_refs.primary_buttons, "奥义: %s" % str(ultimate_id), {
			"command_type": CommandTypesScript.ULTIMATE,
			"skill_id": str(ultimate_id),
		})
	var forced_command_type = str(legal_actions.get("forced_command_type", "")).strip_edges()
	if not forced_command_type.is_empty():
		_add_action_button(controller, view_refs.primary_buttons, "强制: %s" % forced_command_type, {
			"command_type": forced_command_type,
		})
	if bool(legal_actions.get("wait_allowed", false)):
		_add_action_button(controller, view_refs.utility_buttons, "等待", {
			"command_type": CommandTypesScript.WAIT,
		})
	_add_action_button(controller, view_refs.utility_buttons, "投降", {
		"command_type": CommandTypesScript.SURRENDER,
	})
	var switch_targets: Array = legal_actions.get("legal_switch_target_public_ids", [])
	if not switch_targets.is_empty():
		view_refs.switch_label.visible = true
		for target_public_id in switch_targets:
			_add_action_button(controller, view_refs.switch_buttons, "换人: %s" % str(target_public_id), {
				"command_type": CommandTypesScript.SWITCH,
				"target_public_id": str(target_public_id),
			})
	if view_refs.primary_buttons.get_child_count() == 0 \
	and view_refs.switch_buttons.get_child_count() == 0 \
	and view_refs.utility_buttons.get_child_count() == 0:
		_add_info_button(view_refs.primary_buttons, "当前边没有可渲染动作")

func _add_action_button(controller, container: Node, text: String, payload: Dictionary) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 0)
	button.add_theme_stylebox_override("normal", PaletteScript.make_stylebox(PaletteScript.COLOR_CARD_HOVER))
	button.add_theme_stylebox_override("hover", PaletteScript.make_stylebox(PaletteScript.COLOR_BUTTON_PRESSED))
	button.add_theme_color_override("font_color", PaletteScript.COLOR_TEXT)
	button.pressed.connect(func() -> void:
		controller.submit_action(payload)
	)
	container.add_child(button)

func _add_info_button(container: Node, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = true
	button.custom_minimum_size = Vector2(220, 0)
	container.add_child(button)

func _clear_container_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
