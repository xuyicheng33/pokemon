extends RefCounted
class_name SandboxViewPresenter

const BattleUIViewModelBuilderScript := preload("res://src/adapters/battle_ui_view_model_builder.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormatHelperScript := preload("res://src/adapters/sandbox_view_format_helper.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _view_model_builder = BattleUIViewModelBuilderScript.new()
var _fmt = FormatHelperScript.new()

func build_view_model(public_snapshot: Dictionary, context: Dictionary) -> Dictionary:
	return _view_model_builder.build_view_model(public_snapshot, context)

func configure_static_controls(controller) -> void:
	_configure_mode_select(controller._p1_mode_select)
	_configure_mode_select(controller._p2_mode_select)
	controller._battle_seed_input.placeholder_text = str(BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)

func render(controller, current_view_model: Dictionary) -> void:
	if not controller.is_inside_tree() or controller._status_label == null:
		return
	_sync_launch_controls(controller)
	controller._status_label.text = _fmt.format_status_text(controller, current_view_model)
	controller._error_label.text = controller.error_message
	controller._error_label.visible = not controller.error_message.is_empty()
	controller._battle_summary_label.text = _fmt.format_battle_summary_text(controller.battle_summary)
	controller._config_status_label.text = _fmt.format_config_status_text(controller)
	_set_rich_text(controller._p1_summary, _fmt.format_side_text(current_view_model, "P1", controller.side_control_modes))
	_set_rich_text(controller._p2_summary, _fmt.format_side_text(current_view_model, "P2", controller.side_control_modes))
	_set_rich_text(controller._event_log_text, "\n".join(current_view_model.get("recent_event_lines", [])))
	controller._pending_label.text = _fmt.format_pending_text(current_view_model.get("pending_commands", []), controller.battle_summary)
	controller._action_header_label.text = _fmt.format_action_header(controller, current_view_model)
	_render_action_buttons(controller, current_view_model)

func build_launch_config_from_controls(controller) -> Dictionary:
	var next_config: Dictionary = controller.launch_config.duplicate(true)
	next_config["mode"] = BattleSandboxLaunchConfigScript.MODE_MANUAL_MATCHUP
	next_config["demo_profile_id"] = ""
	next_config["matchup_id"] = _selected_option_value(controller._matchup_select)
	next_config["battle_seed"] = int(controller._battle_seed_input.text.to_int())
	next_config["p1_control_mode"] = _selected_option_value(controller._p1_mode_select)
	next_config["p2_control_mode"] = _selected_option_value(controller._p2_mode_select)
	return _launch_config_helper.normalize_config(next_config, controller.available_matchups)

func _render_action_buttons(controller, current_view_model: Dictionary) -> void:
	_clear_container_children(controller._primary_buttons)
	_clear_container_children(controller._switch_buttons)
	_clear_container_children(controller._utility_buttons)
	controller._switch_label.visible = false
	if controller._startup_failed:
		return
	if controller.is_demo_mode:
		_add_info_button(controller._primary_buttons, "Demo 回放模式：%s" % controller.demo_profile)
		return
	if _fmt.has_battle_result(controller.public_snapshot):
		_add_info_button(controller._primary_buttons, "对局已结束，可按当前配置重开")
		return
	var side_id = str(current_view_model.get("current_side_to_select", "")).strip_edges()
	if side_id.is_empty():
		_add_info_button(controller._primary_buttons, "等待下一步状态同步")
		return
	if _fmt.is_policy_side(controller.side_control_modes, side_id):
		_add_info_button(controller._primary_buttons, "%s 当前由 policy 控制" % side_id)
		return
	var legal_actions: Dictionary = current_view_model.get("legal_actions_by_side", {}).get(side_id, {})
	if legal_actions.is_empty():
		_add_info_button(controller._primary_buttons, "当前边缺少合法动作")
		return
	for skill_id in legal_actions.get("legal_skill_ids", []):
		_add_action_button(controller, controller._primary_buttons, "技能: %s" % str(skill_id), {
			"command_type": CommandTypesScript.SKILL,
			"skill_id": str(skill_id),
		})
	for ultimate_id in legal_actions.get("legal_ultimate_ids", []):
		_add_action_button(controller, controller._primary_buttons, "奥义: %s" % str(ultimate_id), {
			"command_type": CommandTypesScript.ULTIMATE,
			"skill_id": str(ultimate_id),
		})
	var forced_command_type = str(legal_actions.get("forced_command_type", "")).strip_edges()
	if not forced_command_type.is_empty():
		_add_action_button(controller, controller._primary_buttons, "强制: %s" % forced_command_type, {
			"command_type": forced_command_type,
		})
	if bool(legal_actions.get("wait_allowed", false)):
		_add_action_button(controller, controller._utility_buttons, "等待", {
			"command_type": CommandTypesScript.WAIT,
		})
	_add_action_button(controller, controller._utility_buttons, "投降", {
		"command_type": CommandTypesScript.SURRENDER,
	})
	var switch_targets: Array = legal_actions.get("legal_switch_target_public_ids", [])
	if not switch_targets.is_empty():
		controller._switch_label.visible = true
		for target_public_id in switch_targets:
			_add_action_button(controller, controller._switch_buttons, "换人: %s" % str(target_public_id), {
				"command_type": CommandTypesScript.SWITCH,
				"target_public_id": str(target_public_id),
			})
	if controller._primary_buttons.get_child_count() == 0 \
	and controller._switch_buttons.get_child_count() == 0 \
	and controller._utility_buttons.get_child_count() == 0:
		_add_info_button(controller._primary_buttons, "当前边没有可渲染动作")


func _sync_launch_controls(controller) -> void:
	_populate_matchup_select(controller)
	_select_option_by_value(controller._p1_mode_select, _fmt.control_mode_for_side(controller.side_control_modes, "P1"))
	_select_option_by_value(controller._p2_mode_select, _fmt.control_mode_for_side(controller.side_control_modes, "P2"))
	controller._battle_seed_input.text = str(int(controller.launch_config.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)))
	var controls_disabled: bool = controller.is_demo_mode or _launch_config_helper.visible_matchup_descriptors(controller.available_matchups).is_empty()
	controller._matchup_select.disabled = controls_disabled
	controller._battle_seed_input.editable = not controls_disabled
	controller._p1_mode_select.disabled = controls_disabled
	controller._p2_mode_select.disabled = controls_disabled
	controller._restart_button.disabled = controller._startup_failed or (controls_disabled and not controller.is_demo_mode)

func _populate_matchup_select(controller) -> void:
	var visible_matchups: Array = _launch_config_helper.visible_matchup_descriptors(controller.available_matchups)
	controller._matchup_select.clear()
	for descriptor in visible_matchups:
		if not (descriptor is Dictionary):
			continue
		var matchup_id = str(descriptor.get("matchup_id", "")).strip_edges()
		if matchup_id.is_empty():
			continue
		_add_option_item(controller._matchup_select, matchup_id)
	if controller._matchup_select.item_count == 0:
		_add_option_item(controller._matchup_select, "no_available_matchups")
		controller._matchup_select.disabled = true
	else:
		controller._matchup_select.disabled = false
	_select_option_by_value(controller._matchup_select, str(controller.launch_config.get("matchup_id", "")))

func _configure_mode_select(option_button: OptionButton) -> void:
	option_button.clear()
	_add_option_item(option_button, BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)
	_add_option_item(option_button, BattleSandboxLaunchConfigScript.CONTROL_MODE_POLICY)

func _selected_option_value(option_button: OptionButton) -> String:
	if option_button == null or option_button.item_count == 0 or option_button.selected < 0:
		return ""
	return str(option_button.get_item_text(option_button.selected)).strip_edges()

func _select_option_by_value(option_button: OptionButton, value: String) -> void:
	if option_button == null:
		return
	for item_index in range(option_button.item_count):
		if str(option_button.get_item_text(item_index)).strip_edges() == value:
			option_button.select(item_index)
			return
	if option_button.item_count > 0:
		option_button.select(0)

func _add_option_item(option_button: OptionButton, text: String) -> void:
	option_button.add_item(text)

func _add_action_button(controller, container: Node, text: String, payload: Dictionary) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 0)
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

func _set_rich_text(widget: RichTextLabel, text: String) -> void:
	widget.clear()
	widget.append_text(text if not text.is_empty() else "-")

