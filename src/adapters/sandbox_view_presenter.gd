extends RefCounted
class_name SandboxViewPresenter

const BattleUIViewModelBuilderScript := preload("res://src/adapters/battle_ui_view_model_builder.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormatHelperScript := preload("res://src/adapters/sandbox_view_format_helper.gd")

const COLOR_CARD := Color(0.13, 0.145, 0.168)
const COLOR_CARD_HOVER := Color(0.18, 0.195, 0.22)
const COLOR_LINE := Color(0.38, 0.38, 0.34, 0.75)
const COLOR_TEXT := Color(0.91, 0.89, 0.84)
const COLOR_MUTED := Color(0.67, 0.67, 0.62)
const COLOR_ACCENT := Color(0.77, 0.66, 0.43)
const CHARACTER_OPTIONS := [
	{
		"display_name": "五条悟",
		"matchup_id": "gojo_vs_sample",
		"types": "space / psychic",
		"tagline": "空间压制与精准控制",
		"sigil": "∞",
		"portrait_path": "res://assets/ui/portraits/gojo.svg",
		"color": Color(0.62, 0.9, 0.96),
	},
	{
		"display_name": "宿傩",
		"matchup_id": "sukuna_setup",
		"types": "fire / demon",
		"tagline": "高压斩击与领域爆发",
		"sigil": "炎",
		"portrait_path": "res://assets/ui/portraits/sukuna.svg",
		"color": Color(0.9, 0.18, 0.13),
	},
	{
		"display_name": "鹿紫云一",
		"matchup_id": "kashimo_vs_sample",
		"types": "thunder / fighting",
		"tagline": "雷电节奏与近身进攻",
		"sigil": "雷",
		"portrait_path": "res://assets/ui/portraits/kashimo.svg",
		"color": Color(0.95, 0.82, 0.18),
	},
	{
		"display_name": "宇智波带土",
		"matchup_id": "obito_vs_sample",
		"types": "light / dark",
		"tagline": "光暗轮转与持久压迫",
		"sigil": "●",
		"portrait_path": "res://assets/ui/portraits/obito.svg",
		"color": Color(0.58, 0.45, 0.9),
	},
]

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _view_model_builder = BattleUIViewModelBuilderScript.new()
var _fmt = FormatHelperScript.new()

func build_view_model(public_snapshot: Dictionary, context: Dictionary) -> Dictionary:
	return _view_model_builder.build_view_model(public_snapshot, context)

func configure_static_controls(view_refs: SandboxViewRefs) -> void:
	_configure_mode_select(view_refs.p1_mode_select)
	_configure_mode_select(view_refs.p2_mode_select)
	view_refs.battle_seed_input.placeholder_text = str(BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)

func render(controller, state: SandboxSessionState, view_refs: SandboxViewRefs, current_view_model: Dictionary) -> void:
	if not controller.is_inside_tree() or not view_refs.is_bound():
		return
	_sync_launch_controls(state, view_refs)
	view_refs.status_label.text = _fmt.format_status_text(state, current_view_model)
	view_refs.error_label.text = state.error_message
	view_refs.error_label.visible = not state.error_message.is_empty()
	view_refs.battle_summary_label.text = _fmt.format_battle_summary_text(state.battle_summary)
	_render_page_state(controller, state, view_refs, current_view_model)
	view_refs.config_status_label.text = _fmt.format_config_status_text(state)
	view_refs.event_header_label.text = _fmt.format_event_header_text(state, current_view_model)
	_set_rich_text(view_refs.p1_summary, _fmt.format_side_text(current_view_model, "P1", state.side_control_modes))
	_set_rich_text(view_refs.p2_summary, _fmt.format_side_text(current_view_model, "P2", state.side_control_modes))
	_set_rich_text(view_refs.event_log_text, "\n".join(current_view_model.get("recent_event_lines", [])))
	view_refs.pending_label.text = _fmt.format_pending_text(current_view_model, state.battle_summary)
	view_refs.action_header_label.text = _fmt.format_action_header(state, current_view_model)
	_set_rich_text(view_refs.result_summary, _format_result_text(state, current_view_model))
	_render_character_cards(controller, state, view_refs)
	_render_replay_controls(view_refs, current_view_model)
	_render_action_buttons(controller, state, view_refs, current_view_model)

func battle_finished(public_snapshot: Dictionary) -> bool:
	return _fmt.has_battle_result(public_snapshot)

func build_launch_config_from_controls(state: SandboxSessionState, view_refs: SandboxViewRefs) -> Dictionary:
	var next_config: Dictionary = state.launch_config.duplicate(true)
	next_config["mode"] = BattleSandboxLaunchConfigScript.MODE_MANUAL_MATCHUP
	next_config["demo_profile_id"] = ""
	next_config["matchup_id"] = _selected_option_value(view_refs.matchup_select)
	next_config["battle_seed"] = int(view_refs.battle_seed_input.text.to_int())
	next_config["p1_control_mode"] = _selected_option_value(view_refs.p1_mode_select)
	next_config["p2_control_mode"] = _selected_option_value(view_refs.p2_mode_select)
	return _launch_config_helper.normalize_config(next_config, state.available_matchups)

func _render_action_buttons(controller, state: SandboxSessionState, view_refs: SandboxViewRefs, current_view_model: Dictionary) -> void:
	_clear_container_children(view_refs.primary_buttons)
	_clear_container_children(view_refs.switch_buttons)
	_clear_container_children(view_refs.utility_buttons)
	view_refs.switch_label.visible = false
	if state.startup_failed:
		return
	if _current_player_ui_mode(controller, state) == "select":
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

func _sync_launch_controls(state: SandboxSessionState, view_refs: SandboxViewRefs) -> void:
	_populate_matchup_select(state, view_refs)
	_select_option_by_value(view_refs.p1_mode_select, _fmt.control_mode_for_side(state.side_control_modes, "P1"))
	_select_option_by_value(view_refs.p2_mode_select, _fmt.control_mode_for_side(state.side_control_modes, "P2"))
	view_refs.battle_seed_input.text = str(int(state.launch_config.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)))
	var controls_disabled: bool = state.is_demo_mode or _launch_config_helper.visible_matchup_descriptors(state.available_matchups).is_empty()
	view_refs.matchup_select.disabled = controls_disabled
	view_refs.battle_seed_input.editable = not controls_disabled
	view_refs.p1_mode_select.disabled = controls_disabled
	view_refs.p2_mode_select.disabled = controls_disabled
	view_refs.restart_button.disabled = state.startup_failed or (controls_disabled and not state.is_demo_mode)

func _render_page_state(controller, state: SandboxSessionState, view_refs: SandboxViewRefs, current_view_model: Dictionary) -> void:
	var mode := _current_player_ui_mode(controller, state)
	if mode != "select" and _fmt.has_battle_result(state.public_snapshot):
		mode = "result"
	view_refs.select_panel.visible = mode == "select"
	view_refs.body_row.visible = mode == "battle"
	view_refs.action_panel.visible = mode == "battle"
	view_refs.result_panel.visible = mode == "result"
	view_refs.battle_summary_label.visible = mode != "select"
	if mode == "select":
		view_refs.status_label.text = "选择一位角色进入预设对局"
		view_refs.battle_summary_label.text = "P1 手动操作，P2 自动行动"
	elif mode == "result":
		view_refs.status_label.text = _format_result_title(state)
	else:
		view_refs.status_label.text = _fmt.format_status_text(state, current_view_model)

func _render_character_cards(controller, state: SandboxSessionState, view_refs: SandboxViewRefs) -> void:
	_clear_container_children(view_refs.character_cards)
	var available_ids := _available_matchup_ids(state.available_matchups)
	for option in CHARACTER_OPTIONS:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _stylebox(COLOR_CARD))
		view_refs.character_cards.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 8)
		card.add_child(content)
		var portrait := PanelContainer.new()
		portrait.custom_minimum_size = Vector2(0, 96)
		portrait.add_theme_stylebox_override("panel", _stylebox(option.get("color", COLOR_ACCENT)))
		content.add_child(portrait)
		var portrait_texture = load(str(option.get("portrait_path", "")))
		if portrait_texture is Texture2D:
			var texture_rect := TextureRect.new()
			texture_rect.texture = portrait_texture
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.custom_minimum_size = Vector2(0, 96)
			portrait.add_child(texture_rect)
		else:
			var sigil := Label.new()
			sigil.text = str(option.get("sigil", ""))
			sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sigil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sigil.add_theme_font_size_override("font_size", 42)
			sigil.add_theme_color_override("font_color", Color(0.06, 0.06, 0.07))
			portrait.add_child(sigil)
		var name_label := _new_card_label(str(option.get("display_name", "")), 18, COLOR_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(name_label)
		var type_label := _new_card_label(str(option.get("types", "")), 12, COLOR_ACCENT)
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(type_label)
		var tagline := _new_card_label(str(option.get("tagline", "")), 13, COLOR_MUTED)
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(tagline)
		var matchup_id := str(option.get("matchup_id", "")).strip_edges()
		var start_button := Button.new()
		start_button.text = "进入战斗"
		start_button.disabled = not available_ids.has(matchup_id)
		start_button.custom_minimum_size = Vector2(0, 36)
		start_button.add_theme_stylebox_override("normal", _stylebox(COLOR_CARD_HOVER))
		start_button.add_theme_stylebox_override("hover", _stylebox(Color(0.23, 0.21, 0.16)))
		start_button.add_theme_color_override("font_color", COLOR_TEXT)
		start_button.pressed.connect(func() -> void:
			controller.start_player_matchup(matchup_id)
		)
		content.add_child(start_button)

func _format_result_title(state: SandboxSessionState) -> String:
	var winner := str(state.battle_summary.get("winner_side_id", "")).strip_edges()
	if winner.is_empty():
		return "战斗结束"
	return "战斗结束 | 胜方 %s" % winner

func _format_result_text(state: SandboxSessionState, current_view_model: Dictionary) -> String:
	var lines: Array = []
	lines.append(_fmt.format_battle_summary_text(state.battle_summary))
	var battle_result = state.public_snapshot.get("battle_result", null)
	if battle_result is Dictionary:
		lines.append("结果：winner=%s | reason=%s | type=%s" % [
			_fmt.value_or_dash(str(battle_result.get("winner_side_id", "")).strip_edges()),
			_fmt.value_or_dash(str(battle_result.get("reason", "")).strip_edges()),
			_fmt.value_or_dash(str(battle_result.get("result_type", "")).strip_edges()),
		])
	lines.append("")
	lines.append(_fmt.format_side_text(current_view_model, "P1", state.side_control_modes))
	lines.append("")
	lines.append(_fmt.format_side_text(current_view_model, "P2", state.side_control_modes))
	return "\n".join(lines)

func _available_matchup_ids(available_matchups: Array) -> Dictionary:
	var ids := {}
	for raw_descriptor in _launch_config_helper.visible_matchup_descriptors(available_matchups):
		if not (raw_descriptor is Dictionary):
			continue
		var matchup_id := str(raw_descriptor.get("matchup_id", "")).strip_edges()
		if not matchup_id.is_empty():
			ids[matchup_id] = true
	return ids

func _current_player_ui_mode(controller, state: SandboxSessionState) -> String:
	if controller != null and controller.has_method("player_ui_mode"):
		var mode := str(controller.player_ui_mode()).strip_edges()
		if not mode.is_empty():
			return mode
	if _fmt.has_battle_result(state.public_snapshot):
		return "result"
	return "battle"

func _new_card_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _render_replay_controls(view_refs: SandboxViewRefs, current_view_model: Dictionary) -> void:
	var replay_mode := bool(current_view_model.get("replay_mode", false))
	view_refs.replay_controls.visible = replay_mode
	if not replay_mode:
		view_refs.replay_turn_label.text = ""
		return
	var replay_frame_index := int(current_view_model.get("replay_frame_index", 0))
	var replay_frame_count := int(current_view_model.get("replay_frame_count", 0))
	view_refs.replay_turn_label.text = _fmt.format_replay_turn_label(current_view_model)
	view_refs.replay_prev_button.disabled = replay_frame_count <= 1 or replay_frame_index <= 0
	view_refs.replay_next_button.disabled = replay_frame_count <= 1 or replay_frame_index >= replay_frame_count - 1

func _populate_matchup_select(state: SandboxSessionState, view_refs: SandboxViewRefs) -> void:
	var visible_matchups: Array = _launch_config_helper.visible_matchup_descriptors(state.available_matchups)
	view_refs.matchup_select.clear()
	for descriptor in visible_matchups:
		if not (descriptor is Dictionary):
			continue
		var matchup_id = str(descriptor.get("matchup_id", "")).strip_edges()
		if matchup_id.is_empty():
			continue
		_add_option_item(view_refs.matchup_select, matchup_id)
	if view_refs.matchup_select.item_count == 0:
		_add_option_item(view_refs.matchup_select, "no_available_matchups")
		view_refs.matchup_select.disabled = true
	else:
		view_refs.matchup_select.disabled = false
	_select_option_by_value(view_refs.matchup_select, str(state.launch_config.get("matchup_id", "")))

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
	button.add_theme_stylebox_override("normal", _stylebox(COLOR_CARD_HOVER))
	button.add_theme_stylebox_override("hover", _stylebox(Color(0.23, 0.21, 0.16)))
	button.add_theme_color_override("font_color", COLOR_TEXT)
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

func _stylebox(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = COLOR_LINE
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 10
	box.content_margin_top = 8
	box.content_margin_right = 10
	box.content_margin_bottom = 8
	return box
