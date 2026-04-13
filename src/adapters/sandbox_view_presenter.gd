extends RefCounted
class_name SandboxViewPresenter

const BattleUIViewModelBuilderScript := preload("res://src/adapters/battle_ui_view_model_builder.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _view_model_builder = BattleUIViewModelBuilderScript.new()

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
	controller._status_label.text = _format_status_text(controller, current_view_model)
	controller._error_label.text = controller.error_message
	controller._error_label.visible = not controller.error_message.is_empty()
	controller._battle_summary_label.text = _format_battle_summary_text(controller.battle_summary)
	controller._config_status_label.text = _format_config_status_text(controller)
	_set_rich_text(controller._p1_summary, _format_side_text(current_view_model, "P1", controller.side_control_modes))
	_set_rich_text(controller._p2_summary, _format_side_text(current_view_model, "P2", controller.side_control_modes))
	_set_rich_text(controller._event_log_text, "\n".join(current_view_model.get("recent_event_lines", [])))
	controller._pending_label.text = _format_pending_text(current_view_model.get("pending_commands", []))
	controller._action_header_label.text = _format_action_header(controller, current_view_model)
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
	if _has_battle_result(controller.public_snapshot):
		_add_info_button(controller._primary_buttons, "对局已结束，可按当前配置重开")
		return
	var side_id = str(current_view_model.get("current_side_to_select", "")).strip_edges()
	if side_id.is_empty():
		_add_info_button(controller._primary_buttons, "等待下一步状态同步")
		return
	if _is_policy_side(controller.side_control_modes, side_id):
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

func _format_status_text(controller, current_view_model: Dictionary) -> String:
	var mode_text = "demo=%s" % controller.demo_profile if controller.is_demo_mode else "manual hotseat"
	var field_id = str(current_view_model.get("field_id", "")).strip_edges()
	var current_side = str(current_view_model.get("current_side_to_select", "")).strip_edges()
	var result_text = ""
	if not controller.battle_summary.is_empty():
		result_text = " | result=%s/%s" % [
			str(controller.battle_summary.get("result_type", "")),
			str(controller.battle_summary.get("reason", "")),
		]
	return "mode=%s | turn=%d | phase=%s | field=%s | current=%s%s" % [
		mode_text,
		int(current_view_model.get("turn_index", 0)),
		str(current_view_model.get("phase", "")),
		field_id if not field_id.is_empty() else "-",
		current_side if not current_side.is_empty() else "-",
		result_text,
	]

func _format_config_status_text(controller) -> String:
	if controller.is_demo_mode:
		return "当前配置：demo=%s（CLI 调试入口，启动控件已禁用）" % controller.demo_profile
	return "当前配置：%s" % _launch_config_helper.build_config_summary(controller.launch_config)

func _format_battle_summary_text(battle_summary: Dictionary) -> String:
	if battle_summary.is_empty():
		return "对局摘要: -"
	return "对局摘要: winner=%s | reason=%s | result=%s | turn=%d | events=%d" % [
		str(battle_summary.get("winner_side_id", "-")),
		str(battle_summary.get("reason", "")),
		str(battle_summary.get("result_type", "")),
		int(battle_summary.get("turn_index", 0)),
		int(battle_summary.get("event_log_cursor", 0)),
	]

func _format_side_text(current_view_model: Dictionary, side_id: String, side_control_modes: Dictionary) -> String:
	var side_model = _find_side_model(current_view_model.get("sides", []), side_id)
	if side_model.is_empty():
		return "%s\nmissing side snapshot" % side_id
	var lines = [
		"%s (%s)" % [side_id, _control_mode_for_side(side_control_modes, side_id)],
		_format_unit_block("Active", side_model.get("active", {})),
		_format_unit_list("Bench", side_model.get("bench", [])),
		_format_unit_list("Team", side_model.get("team_units", [])),
	]
	return "\n".join(lines)

func _format_unit_block(label: String, unit_model: Dictionary) -> String:
	if unit_model.is_empty():
		return "%s: -" % label
	var effect_text = _format_effects(unit_model.get("effects", []))
	return "%s: %s [%s]\nHP %d/%d | MP %d/%d | UP %d/%d req=%d\nType %s | Leave %s/%s\nEffects %s" % [
		label,
		str(unit_model.get("display_name", "")),
		str(unit_model.get("public_id", "")),
		int(unit_model.get("current_hp", 0)),
		int(unit_model.get("max_hp", 0)),
		int(unit_model.get("current_mp", 0)),
		int(unit_model.get("max_mp", 0)),
		int(unit_model.get("ultimate_points", 0)),
		int(unit_model.get("ultimate_points_cap", 0)),
		int(unit_model.get("ultimate_points_required", 0)),
		",".join(unit_model.get("combat_type_ids", [])),
		str(unit_model.get("leave_state", "-")),
		str(unit_model.get("leave_reason", "-")),
		effect_text,
	]

func _format_unit_list(label: String, units: Array) -> String:
	if units.is_empty():
		return "%s: -" % label
	var lines: Array = ["%s:" % label]
	for unit_model in units:
		if not (unit_model is Dictionary):
			continue
		lines.append("- %s [%s] HP %d/%d MP %d/%d UP %d/%d" % [
			str(unit_model.get("display_name", "")),
			str(unit_model.get("public_id", "")),
			int(unit_model.get("current_hp", 0)),
			int(unit_model.get("max_hp", 0)),
			int(unit_model.get("current_mp", 0)),
			int(unit_model.get("max_mp", 0)),
			int(unit_model.get("ultimate_points", 0)),
			int(unit_model.get("ultimate_points_cap", 0)),
		])
	return "\n".join(lines)

func _format_effects(effects: Array) -> String:
	if effects.is_empty():
		return "-"
	var entries: Array = []
	for effect_model in effects:
		if not (effect_model is Dictionary):
			continue
		entries.append("%s(%d)" % [
			str(effect_model.get("effect_definition_id", "")),
			int(effect_model.get("remaining", 0)),
		])
	return ", ".join(entries) if not entries.is_empty() else "-"

func _format_pending_text(pending_summaries: Array) -> String:
	if pending_summaries.is_empty():
		return "待提交指令: -"
	var entries: Array = []
	for pending_summary in pending_summaries:
		if not (pending_summary is Dictionary):
			continue
		var entry = "%s:%s" % [
			str(pending_summary.get("side_id", "")),
			str(pending_summary.get("command_type", "")),
		]
		var skill_id = str(pending_summary.get("skill_id", "")).strip_edges()
		var target_public_id = str(pending_summary.get("target_public_id", "")).strip_edges()
		if not skill_id.is_empty():
			entry += " skill=%s" % skill_id
		if not target_public_id.is_empty():
			entry += " target=%s" % target_public_id
		entries.append(entry)
	return "待提交指令: %s" % " | ".join(entries)

func _format_action_header(controller, current_view_model: Dictionary) -> String:
	if controller._startup_failed:
		return "场景初始化失败"
	if controller.is_demo_mode:
		return "旧回放入口：demo=%s" % controller.demo_profile
	if _has_battle_result(controller.public_snapshot):
		return "结算态"
	var side_id = str(current_view_model.get("current_side_to_select", "")).strip_edges()
	if side_id.is_empty():
		return "等待下一步"
	var legal_actions: Dictionary = current_view_model.get("legal_actions_by_side", {}).get(side_id, {})
	var actor_public_id = str(legal_actions.get("actor_public_id", "")).strip_edges()
	return "当前待选边: %s | actor=%s | control=%s" % [
		side_id,
		actor_public_id if not actor_public_id.is_empty() else "-",
		_control_mode_for_side(controller.side_control_modes, side_id),
	]

func _sync_launch_controls(controller) -> void:
	_populate_matchup_select(controller)
	_select_option_by_value(controller._p1_mode_select, _control_mode_for_side(controller.side_control_modes, "P1"))
	_select_option_by_value(controller._p2_mode_select, _control_mode_for_side(controller.side_control_modes, "P2"))
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

func _find_side_model(side_models: Array, side_id: String) -> Dictionary:
	for side_model in side_models:
		if side_model is Dictionary and str(side_model.get("side_id", "")) == side_id:
			return side_model
	return {}

func _control_mode_for_side(side_control_modes: Dictionary, side_id: String) -> String:
	return str(side_control_modes.get(side_id, BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)).strip_edges()

func _is_policy_side(side_control_modes: Dictionary, side_id: String) -> bool:
	return _launch_config_helper.is_policy_control_mode(_control_mode_for_side(side_control_modes, side_id))

func _has_battle_result(public_snapshot: Dictionary) -> bool:
	var battle_result = public_snapshot.get("battle_result", null)
	return battle_result is Dictionary and bool(battle_result.get("finished", false))
