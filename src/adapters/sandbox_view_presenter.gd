extends RefCounted
class_name SandboxViewPresenter

const ActionButtonsRendererScript := preload("res://src/adapters/sandbox_view_action_buttons_renderer.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const BattleUIViewModelBuilderScript := preload("res://src/adapters/battle_ui_view_model_builder.gd")
const CharacterCardsRendererScript := preload("res://src/adapters/sandbox_view_character_cards_renderer.gd")
const FormatHelperScript := preload("res://src/adapters/sandbox_view_format_helper.gd")
const PaletteScript := preload("res://src/adapters/sandbox_view_palette.gd")

var _action_buttons_renderer = ActionButtonsRendererScript.new()
var _character_cards_renderer = CharacterCardsRendererScript.new()
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
	_update_responsive_layout(controller, view_refs)
	var visible_matchups: Array = _launch_config_helper.visible_matchup_descriptors(state.available_matchups)
	var current_player_ui_mode := _resolved_player_ui_mode(controller, state)
	_sync_launch_controls(state, view_refs, visible_matchups)
	view_refs.status_label.text = _fmt.format_status_text(state, current_view_model)
	view_refs.error_label.text = state.error_message
	view_refs.error_label.visible = not state.error_message.is_empty()
	view_refs.battle_summary_label.text = _fmt.format_battle_summary_text(state.battle_summary)
	_render_page_state(state, view_refs, current_view_model, current_player_ui_mode)
	view_refs.config_status_label.text = _fmt.format_config_status_text(state)
	view_refs.event_header_label.text = _fmt.format_event_header_text(state, current_view_model)
	_set_rich_text(view_refs.p1_summary, _fmt.format_side_text(current_view_model, "P1", state.side_control_modes))
	_set_rich_text(view_refs.p2_summary, _fmt.format_side_text(current_view_model, "P2", state.side_control_modes))
	_set_rich_text(view_refs.event_log_text, "\n".join(current_view_model.get("recent_event_lines", [])))
	view_refs.pending_label.text = _fmt.format_pending_text(current_view_model, state.battle_summary)
	view_refs.action_header_label.text = _fmt.format_action_header(state, current_view_model)
	_set_rich_text(view_refs.result_summary, _format_result_text(state, current_view_model))
	if current_player_ui_mode == "select":
		_character_cards_renderer.render(controller, state, view_refs, visible_matchups)
	_render_replay_controls(view_refs, current_view_model)
	_action_buttons_renderer.render(controller, state, view_refs, current_view_model, current_player_ui_mode)

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

func _sync_launch_controls(state: SandboxSessionState, view_refs: SandboxViewRefs, visible_matchups: Array) -> void:
	_populate_matchup_select(state, view_refs, visible_matchups)
	_select_option_by_value(view_refs.p1_mode_select, _fmt.control_mode_for_side(state.side_control_modes, "P1"))
	_select_option_by_value(view_refs.p2_mode_select, _fmt.control_mode_for_side(state.side_control_modes, "P2"))
	view_refs.battle_seed_input.text = str(int(state.launch_config.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)))
	var controls_disabled: bool = state.is_demo_mode or visible_matchups.is_empty()
	view_refs.matchup_select.disabled = controls_disabled
	view_refs.battle_seed_input.editable = not controls_disabled
	view_refs.p1_mode_select.disabled = controls_disabled
	view_refs.p2_mode_select.disabled = controls_disabled
	view_refs.restart_button.disabled = state.startup_failed or (controls_disabled and not state.is_demo_mode)

func _render_page_state(state: SandboxSessionState, view_refs: SandboxViewRefs, current_view_model: Dictionary, mode: String) -> void:
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

func _current_player_ui_mode(controller, state: SandboxSessionState) -> String:
	return _resolved_player_ui_mode(controller, state)

func _resolved_player_ui_mode(controller, state: SandboxSessionState) -> String:
	if controller != null:
		var mode := str(controller.player_ui_mode()).strip_edges()
		if not mode.is_empty():
			if mode != "select" and _fmt.has_battle_result(state.public_snapshot):
				return "result"
			return mode
	if _fmt.has_battle_result(state.public_snapshot):
		return "result"
	return "battle"

func _update_responsive_layout(controller, view_refs: SandboxViewRefs) -> void:
	var width := int(controller.size.x)
	if width <= 0 and controller.get_viewport() != null:
		width = int(controller.get_viewport().get_visible_rect().size.x)
	if width >= 1200:
		view_refs.character_cards.columns = 4
	elif width >= 900:
		view_refs.character_cards.columns = 2
	else:
		view_refs.character_cards.columns = 1

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

func _populate_matchup_select(state: SandboxSessionState, view_refs: SandboxViewRefs, visible_matchups: Array) -> void:
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

func _set_rich_text(widget: RichTextLabel, text: String) -> void:
	widget.clear()
	widget.append_text(text if not text.is_empty() else "-")
