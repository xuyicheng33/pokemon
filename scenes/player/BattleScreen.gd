extends Control
class_name PlayerBattleScreen

## 中文宝可梦风格三段式 BattleScreen Controller。
##
## 职责：
##   1. 启动 PlayerBattleSession + PlayerContentLexicon + PlayerEventLogStreamer。
##   2. 把 public_snapshot 渲染成 TopBar / OpponentZone / MiddleLog / PlayerZone /
##      ActionBar / Bench 等区域；按钮信号路由回 session.submit_player_command。
##   3. 终局展示 PlayerWinPanel；错误展示 PlayerErrorToast；强制换人弹 ForcedReplaceDialog。
##
## 不直接耦合 BattleCoreManager；所有 snapshot 都从 PlayerBattleSession 拉。

const PlayerBattleSessionScript := preload("res://src/adapters/player/player_battle_session.gd")
const PlayerContentLexiconScript := preload("res://src/adapters/player/player_content_lexicon.gd")
const PlayerEventLogStreamerScript := preload("res://src/adapters/player/player_event_log_streamer.gd")
const PlayerBattleScreenViewRendererScript := preload("res://scenes/player/BattleScreenViewRenderer.gd")
const PlayerBattleScreenMatchupSelectorScript := preload("res://scenes/player/BattleScreenMatchupSelector.gd")
const ErrorToastScene := preload("res://scenes/player/ErrorToast.tscn")
const WinPanelScene := preload("res://scenes/player/WinPanel.tscn")
const ForcedReplaceDialogScene := preload("res://scenes/player/ForcedReplaceDialog.tscn")

# 默认对局配置
const DEFAULT_MATCHUP_ID: String = "gojo_vs_sample"
const DEFAULT_SEED: int = 9101
const LOCAL_PLAYER_SIDE_ID: String = "P1"

# 命令类型常量（与 manager / session 协议保持一致）
const CMD_CAST: String = "skill"
const CMD_ULTIMATE: String = "ultimate"
const CMD_SWITCH: String = "switch"
const CMD_WAIT: String = "wait"
const CMD_FORCED_DEFAULT: String = "resource_forced_default"

# ---- 节点引用 ----
@onready var _turn_label: Label = $MainScroll/MarginContainer/VBoxContainer/TopBar/TurnLabel
@onready var _field_badge_label: Label = $MainScroll/MarginContainer/VBoxContainer/TopBar/FieldBadge/FieldLabel
@onready var _matchup_select: OptionButton = $MainScroll/MarginContainer/VBoxContainer/TopBar/MatchupSelect
@onready var _start_matchup_button: Button = $MainScroll/MarginContainer/VBoxContainer/TopBar/StartMatchupButton
@onready var _current_side_label: Label = $MainScroll/MarginContainer/VBoxContainer/TopBar/CurrentSideLabel

@onready var _opponent_name_label: Label = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/HeaderRow/NameLabel
@onready var _opponent_combat_type_row: HBoxContainer = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/HeaderRow/CombatTypeBadgeRow
@onready var _opponent_hp_bar: ProgressBar = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/HPRow/HPBar
@onready var _opponent_hp_label: Label = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/HPRow/HPLabel
@onready var _opponent_mp_bar: ProgressBar = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/MPRow/MPBar
@onready var _opponent_mp_label: Label = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/MPRow/MPLabel
@onready var _opponent_ultimate_dots: HBoxContainer = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/UltimateDots
@onready var _opponent_stat_stages_row: HBoxContainer = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/StatStagesRow
@onready var _opponent_effects_box: VBoxContainer = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/EffectsBox
@onready var _opponent_sprite: ColorRect = $MainScroll/MarginContainer/VBoxContainer/OpponentZone/OpponentSprite

@onready var _opponent_bench_row: HBoxContainer = $MainScroll/MarginContainer/VBoxContainer/OpponentBenchRow

@onready var _log_text: PlayerLogText = $MainScroll/MarginContainer/VBoxContainer/MiddleLog/ScrollContainer/LogText

@onready var _player_name_label: Label = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/HeaderRow/NameLabel
@onready var _player_combat_type_row: HBoxContainer = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/HeaderRow/CombatTypeBadgeRow
@onready var _player_hp_bar: ProgressBar = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/HPRow/HPBar
@onready var _player_hp_label: Label = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/HPRow/HPLabel
@onready var _player_mp_bar: ProgressBar = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/MPRow/MPBar
@onready var _player_mp_label: Label = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/MPRow/MPLabel
@onready var _player_ultimate_dots: HBoxContainer = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/UltimateDots
@onready var _player_stat_stages_row: HBoxContainer = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/StatStagesRow
@onready var _player_effects_box: VBoxContainer = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/EffectsBox
@onready var _player_sprite: ColorRect = $MainScroll/MarginContainer/VBoxContainer/PlayerZone/PlayerSprite

@onready var _player_bench_row: HBoxContainer = $MainScroll/MarginContainer/VBoxContainer/PlayerBenchRow

@onready var _skill_button_0: Button = $MainScroll/MarginContainer/VBoxContainer/ActionBar/SkillButton_0
@onready var _skill_button_1: Button = $MainScroll/MarginContainer/VBoxContainer/ActionBar/SkillButton_1
@onready var _skill_button_2: Button = $MainScroll/MarginContainer/VBoxContainer/ActionBar/SkillButton_2
@onready var _skill_button_3: Button = $MainScroll/MarginContainer/VBoxContainer/ActionBar/SkillButton_3
@onready var _ultimate_button: Button = $MainScroll/MarginContainer/VBoxContainer/ActionBar/UltimateButton
@onready var _switch_menu_button: Button = $MainScroll/MarginContainer/VBoxContainer/ActionBar/SwitchMenuButton
@onready var _wait_button: Button = $MainScroll/MarginContainer/VBoxContainer/ActionBar/WaitButton
@onready var _forced_hint_label: Label = $MainScroll/MarginContainer/VBoxContainer/ActionBar/ForcedHintLabel

@onready var _side_detail_panel: PanelContainer = $MainScroll/MarginContainer/VBoxContainer/SideDetailPanel
@onready var _error_toast_container: CanvasLayer = $ErrorToastContainer
@onready var _win_panel_container: CanvasLayer = $WinPanelContainer
@onready var _dialog_container: CanvasLayer = $DialogContainer

# ---- 运行态 ----
var _session: PlayerBattleSession = null
var _lexicon: PlayerContentLexicon = null
var _event_log_streamer: PlayerEventLogStreamer = null
var _view_renderer: PlayerBattleScreenViewRenderer = PlayerBattleScreenViewRendererScript.new()
var _matchup_selector: PlayerBattleScreenMatchupSelector = PlayerBattleScreenMatchupSelectorScript.new()
var _last_snapshot: Dictionary = {}
var _cached_legal_summary: Dictionary = {}
var _cached_legal_turn_index: int = -1
var _switch_menu_popup: PopupMenu = null
var _switch_menu_options: Array = []
var _matchup_options: Array = []
var _current_matchup_id: String = ""
var _skill_buttons: Array = []
var _force_run_after_idle: bool = false
var _forced_replace_dialog: PlayerForcedReplaceDialog = null
var _win_panel_shown: bool = false


func _ready() -> void:
	_skill_buttons = [_skill_button_0, _skill_button_1, _skill_button_2, _skill_button_3]
	_forced_hint_label.visible = false
	_side_detail_panel.visible = false

	_setup_log_text()
	_setup_buttons()
	_setup_matchup_controls()
	_setup_switch_menu()

	_bootstrap_session()
	_refresh_ui_from_session()


# ---- 启动期 ----

func _bootstrap_session() -> void:
	_lexicon = PlayerContentLexiconScript.new()
	if not _lexicon.load_all():
		_show_toast("invalid_composition", "PlayerContentLexicon 内容加载失败")
		return

	if _log_text != null:
		_log_text.set_lexicon(_lexicon)
	_view_renderer.set_lexicon(_lexicon)
	_matchup_selector.set_lexicon(_lexicon)

	_event_log_streamer = PlayerEventLogStreamerScript.new()
	_session = PlayerBattleSessionScript.new()

	var matchup_id := _populate_matchup_select(DEFAULT_MATCHUP_ID)
	_start_session(matchup_id, DEFAULT_SEED)


func _setup_log_text() -> void:
	if _log_text == null:
		return
	if _log_text.has_method("clear_log"):
		_log_text.clear_log()


func _setup_buttons() -> void:
	for i in _skill_buttons.size():
		var button: Button = _skill_buttons[i]
		if button == null:
			continue
		var index: int = i
		button.pressed.connect(func() -> void: _on_skill_button_pressed(index))
	_ultimate_button.pressed.connect(_on_ultimate_pressed)
	_switch_menu_button.pressed.connect(_on_switch_menu_pressed)
	_wait_button.pressed.connect(_on_wait_pressed)

func _setup_matchup_controls() -> void:
	if _start_matchup_button != null:
		_start_matchup_button.pressed.connect(_on_start_matchup_pressed)


func _setup_switch_menu() -> void:
	_switch_menu_popup = PopupMenu.new()
	_switch_menu_popup.name = "SwitchMenuPopup"
	_switch_menu_popup.id_pressed.connect(_on_switch_menu_item_selected)
	add_child(_switch_menu_popup)


func _populate_matchup_select(preferred_matchup_id: String) -> String:
	var result: Dictionary = _matchup_selector.populate_result(_matchup_select, _session, preferred_matchup_id)
	_matchup_options = result.get("matchup_options", [])
	if not bool(result.get("ok", false)):
		_show_toast("invalid_battle_setup", "玩家对局列表加载失败: %s" % String(result.get("error_message", "unknown error")))
	var selected_matchup_id := _select_matchup_option(preferred_matchup_id)
	if _start_matchup_button != null:
		_start_matchup_button.disabled = _matchup_options.is_empty()
	return selected_matchup_id


func _select_matchup_option(matchup_id: String) -> String:
	return _matchup_selector.select_option(_matchup_select, _matchup_options, matchup_id)


func _start_session(matchup_id: String, battle_seed: int) -> bool:
	if _session == null:
		_session = PlayerBattleSessionScript.new()
	var start_envelope: Dictionary = _session.start(matchup_id, battle_seed)
	if not _handle_envelope(start_envelope):
		return false
	_current_matchup_id = matchup_id
	_last_snapshot = _session.current_snapshot()
	_invalidate_legal_cache()
	_select_matchup_option(matchup_id)
	return true


func _restart_session(matchup_id: String) -> void:
	if _session != null and not _session.session_id.is_empty():
		var close_envelope: Dictionary = _session.close()
		if not _handle_envelope(close_envelope):
			return
	_session = PlayerBattleSessionScript.new()
	_event_log_streamer = PlayerEventLogStreamerScript.new()
	_last_snapshot = {}
	_invalidate_legal_cache()
	_clear_transient_ui()
	_setup_log_text()
	if _start_session(matchup_id, DEFAULT_SEED):
		_refresh_ui_from_session()


func _clear_transient_ui() -> void:
	_win_panel_shown = false
	_forced_replace_dialog = null
	_clear_container_children(_win_panel_container)
	_clear_container_children(_error_toast_container)
	_clear_container_children(_dialog_container)
	if _switch_menu_popup != null:
		_switch_menu_popup.hide()
		_switch_menu_popup.clear()
	_switch_menu_options.clear()


func _clear_container_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


# ---- 按钮回调 ----

func _on_skill_button_pressed(index: int) -> void:
	var legal: Dictionary = _local_legal_action_summary()
	var legal_skill_ids: Array = legal.get("legal_skill_ids", [])
	if index < 0 or index >= legal_skill_ids.size():
		return
	var skill_id: String = str(legal_skill_ids[index])
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	_submit_command({
		"command_type": CMD_CAST,
		"side_id": LOCAL_PLAYER_SIDE_ID,
		"actor_public_id": actor_public_id,
		"skill_id": skill_id,
	})


func _on_ultimate_pressed() -> void:
	var legal: Dictionary = _local_legal_action_summary()
	var legal_ultimate_ids: Array = legal.get("legal_ultimate_ids", [])
	if legal_ultimate_ids.is_empty():
		return
	var ultimate_id: String = str(legal_ultimate_ids[0])
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	_submit_command({
		"command_type": CMD_ULTIMATE,
		"side_id": LOCAL_PLAYER_SIDE_ID,
		"actor_public_id": actor_public_id,
		"skill_id": ultimate_id,
	})


func _on_switch_menu_pressed() -> void:
	var legal: Dictionary = _local_legal_action_summary()
	var switch_ids: Array = legal.get("legal_switch_target_public_ids", [])
	if switch_ids.is_empty():
		return
	_switch_menu_popup.clear()
	_switch_menu_options.clear()
	for raw_id in switch_ids:
		var public_id := str(raw_id)
		var display_name := _resolve_unit_display_name_from_snapshot(public_id)
		var label := "%s（%s）" % [display_name, public_id] if display_name != public_id else public_id
		_switch_menu_options.append(public_id)
		_switch_menu_popup.add_item(label, _switch_menu_options.size() - 1)
	var pos := _switch_menu_button.global_position + Vector2(0, _switch_menu_button.size.y)
	_switch_menu_popup.position = Vector2i(int(pos.x), int(pos.y))
	_switch_menu_popup.size = Vector2i(220, 0)
	_switch_menu_popup.popup()


func _on_switch_menu_item_selected(item_index: int) -> void:
	if item_index < 0 or item_index >= _switch_menu_options.size():
		return
	var target_public_id: String = _switch_menu_options[item_index]
	var legal: Dictionary = _local_legal_action_summary()
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	_submit_command({
		"command_type": CMD_SWITCH,
		"side_id": LOCAL_PLAYER_SIDE_ID,
		"actor_public_id": actor_public_id,
		"target_public_id": target_public_id,
	})


func _on_wait_pressed() -> void:
	var legal: Dictionary = _local_legal_action_summary()
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	_submit_command({
		"command_type": CMD_WAIT,
		"side_id": LOCAL_PLAYER_SIDE_ID,
		"actor_public_id": actor_public_id,
	})


func _on_start_matchup_pressed() -> void:
	var selected_matchup_id := _matchup_selector.current_selected_matchup_id(_matchup_select, _matchup_options)
	if selected_matchup_id.is_empty():
		return
	_restart_session(selected_matchup_id)


# ---- 命令提交 / 推进 ----

func _submit_command(payload: Dictionary) -> void:
	if _session == null:
		return
	var envelope: Dictionary = _session.submit_player_command(LOCAL_PLAYER_SIDE_ID, payload)
	if not _handle_envelope(envelope):
		_refresh_ui_from_session()
		return
	# P2 由 PlayerDefaultPolicy 自动出招；推进一回合后刷 UI。
	_advance_one_turn()
	_refresh_ui_from_session()


func _advance_one_turn() -> void:
	if _session == null:
		return
	var envelope: Dictionary = _session.run_turn()
	_handle_envelope(envelope)
	_invalidate_legal_cache()


func _refresh_ui_from_session() -> void:
	if _session == null:
		return
	var snapshot: Dictionary = _session.current_snapshot()
	_last_snapshot = snapshot
	if int(snapshot.get("turn_index", -1)) != _cached_legal_turn_index:
		_invalidate_legal_cache()
	_refresh_ui(snapshot)


# ---- UI 刷新 ----

func _refresh_ui(snapshot: Dictionary) -> void:
	_refresh_top_bar(snapshot)
	var sides: Array = snapshot.get("sides", [])
	var local_side: Dictionary = _find_side(sides, LOCAL_PLAYER_SIDE_ID)
	var opponent_side: Dictionary = _find_opposite_side(sides, LOCAL_PLAYER_SIDE_ID)

	_view_renderer.refresh_card(opponent_side, _opponent_name_label, _opponent_combat_type_row,
		_opponent_hp_bar, _opponent_hp_label, _opponent_mp_bar, _opponent_mp_label,
		_opponent_ultimate_dots, _opponent_stat_stages_row, _opponent_effects_box,
		_opponent_sprite)
	_view_renderer.refresh_card(local_side, _player_name_label, _player_combat_type_row,
		_player_hp_bar, _player_hp_label, _player_mp_bar, _player_mp_label,
		_player_ultimate_dots, _player_stat_stages_row, _player_effects_box,
		_player_sprite)

	_view_renderer.refresh_bench(_opponent_bench_row, opponent_side)
	_view_renderer.refresh_bench(_player_bench_row, local_side)

	_refresh_event_log()
	_refresh_action_bar(snapshot)
	_refresh_battle_result(snapshot)


func _refresh_top_bar(snapshot: Dictionary) -> void:
	var turn_index: int = int(snapshot.get("turn_index", 1))
	_turn_label.text = "回合 %d" % maxi(1, turn_index)
	var field_dict: Dictionary = snapshot.get("field", {}) if snapshot.get("field", null) is Dictionary else {}
	var raw_field_id: Variant = snapshot.get("field_id", null)
	var field_id: String = ""
	if raw_field_id != null:
		field_id = str(raw_field_id).strip_edges()
	if field_id == "" and field_dict.has("field_id") and field_dict.get("field_id", null) != null:
		field_id = str(field_dict.get("field_id", "")).strip_edges()
	if field_id == "":
		_field_badge_label.text = "场地: 无"
	else:
		var field_name := _view_renderer.resolve_field_display_name(field_id)
		var raw_remaining: Variant = field_dict.get("remaining_turns", field_dict.get("remaining", null))
		var remaining: int = -1
		if raw_remaining != null:
			remaining = int(raw_remaining)
		if remaining >= 0:
			_field_badge_label.text = "场地: %s（剩 %d 回合）" % [field_name, remaining]
		else:
			_field_badge_label.text = "场地: %s" % field_name

	var current_side: String = ""
	if _session != null:
		current_side = _session.current_side_to_select()
	if current_side == "":
		if _session != null and _session.is_finished():
			_current_side_label.text = "战斗结束"
		else:
			_current_side_label.text = "等待对手"
	elif current_side == LOCAL_PLAYER_SIDE_ID:
		_current_side_label.text = "请选择你的指令"
	else:
		_current_side_label.text = "等待 %s 选择" % current_side


func _refresh_action_bar(snapshot: Dictionary) -> void:
	var legal: Dictionary = _local_legal_action_summary()
	var legal_skill_ids: Array = legal.get("legal_skill_ids", [])
	var legal_ultimate_ids: Array = legal.get("legal_ultimate_ids", [])
	var switch_ids: Array = legal.get("legal_switch_target_public_ids", [])
	var wait_allowed: bool = bool(legal.get("wait_allowed", false))
	var forced_command_type: String = str(legal.get("forced_command_type", "")).strip_edges()
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	var local_side: Dictionary = _find_side(snapshot.get("sides", []), LOCAL_PLAYER_SIDE_ID)
	var actor_unit: Dictionary = _view_renderer.find_unit_by_public_id(local_side, actor_public_id)
	var battle_finished := _session != null and _session.is_finished()
	var our_turn := _session != null and _session.current_side_to_select() == LOCAL_PLAYER_SIDE_ID

	# Skill buttons
	for i in _skill_buttons.size():
		var button: Button = _skill_buttons[i]
		if button == null:
			continue
		if i < legal_skill_ids.size():
			var skill_id := str(legal_skill_ids[i])
			button.text = "%s · %dMP" % [_view_renderer.resolve_skill_display_name(skill_id), _view_renderer.resolve_skill_mp_cost(skill_id)]
			button.disabled = not our_turn
		else:
			button.text = "—"
			button.disabled = true

	# Ultimate
	if legal_ultimate_ids.is_empty():
		_ultimate_button.text = "奥义 —"
		_ultimate_button.disabled = true
	else:
		var first_ult := str(legal_ultimate_ids[0])
		var ult_name := _view_renderer.resolve_skill_display_name(first_ult)
		var points := int(actor_unit.get("ultimate_points", 0))
		var required := int(actor_unit.get("ultimate_points_required", 0))
		var prefix := "奥义 %s" % ult_name
		if required > 0 and points >= required:
			_ultimate_button.text = "%s 满" % prefix
		else:
			_ultimate_button.text = prefix
		_ultimate_button.disabled = not our_turn

	# Switch
	_switch_menu_button.text = "换人 ▼"
	_switch_menu_button.disabled = switch_ids.is_empty() or not our_turn

	# Wait
	_wait_button.text = "等待"
	_wait_button.disabled = (not wait_allowed) or (not our_turn)

	# Forced default：自动反伤场景
	if forced_command_type == CMD_FORCED_DEFAULT:
		_forced_hint_label.visible = true
		_forced_hint_label.text = "无可用主动技能，将自动反伤"
		for button in _skill_buttons:
			if button != null:
				button.disabled = true
		_ultimate_button.disabled = true
		_switch_menu_button.disabled = true
		_wait_button.disabled = true
		# 自动推进一回合（避免在 _ready / 回调链里递归）
		if not _force_run_after_idle and not battle_finished:
			_force_run_after_idle = true
			call_deferred("_force_run_default_then_refresh")
	else:
		_forced_hint_label.visible = false

	# 强制换人弹窗：只能换人时（无 skills/ultimate/wait，仅 switch）
	var must_replace := our_turn \
		and forced_command_type == "" \
		and legal_skill_ids.is_empty() \
		and legal_ultimate_ids.is_empty() \
		and not wait_allowed \
		and not switch_ids.is_empty()
	if must_replace:
		_open_forced_replace_dialog(switch_ids, actor_public_id)
	else:
		_close_forced_replace_dialog()


func _force_run_default_then_refresh() -> void:
	_force_run_after_idle = false
	if _session == null:
		return
	_advance_one_turn()
	_refresh_ui_from_session()


func _refresh_event_log() -> void:
	if _event_log_streamer == null or _session == null or _log_text == null:
		return
	var manager: Variant = _session.manager()
	var session_id: String = _session.session_id
	if manager == null or session_id == "":
		return
	var envelope: Dictionary = _event_log_streamer.pull_increment(manager, session_id)
	if not bool(envelope.get("ok", false)):
		return
	for raw_event in envelope.get("events", []):
		if raw_event is Dictionary:
			_log_text.append_event(raw_event)


func _refresh_battle_result(snapshot: Dictionary) -> void:
	var battle_result = snapshot.get("battle_result", null)
	if not (battle_result is Dictionary):
		return
	var result_dict: Dictionary = battle_result
	if not bool(result_dict.get("finished", false)):
		return
	if _win_panel_shown:
		return
	_win_panel_shown = true
	var panel: PlayerWinPanel = WinPanelScene.instantiate()
	_win_panel_container.add_child(panel)
	panel.set_local_player_side_id(LOCAL_PLAYER_SIDE_ID)
	if not panel.menu_requested.is_connected(_on_win_panel_menu_requested):
		panel.menu_requested.connect(_on_win_panel_menu_requested)
	var winner_side_id = result_dict.get("winner_side_id", null)
	var result_type := str(result_dict.get("result_type", "")).strip_edges()
	var reason := str(result_dict.get("reason", "")).strip_edges()
	panel.show_outcome(winner_side_id, result_type, reason)


func _on_win_panel_menu_requested() -> void:
	# 简单回主入口：reload 当前 scene 即可重新进入 BattleScreen 主流程；
	# 后续若 boot 提供 menu scene，可改为 change_scene_to_file。
	if _session != null:
		var close_envelope: Dictionary = _session.close()
		if not _handle_envelope(close_envelope):
			return
		_session = null
	get_tree().reload_current_scene()


# ---- 强制换人对话框 ----

func _open_forced_replace_dialog(switch_ids: Array, actor_public_id: String) -> void:
	if _dialog_container == null:
		return
	if _forced_replace_dialog != null and _forced_replace_dialog.visible:
		return
	if _forced_replace_dialog == null:
		_forced_replace_dialog = ForcedReplaceDialogScene.instantiate()
		_dialog_container.add_child(_forced_replace_dialog)
		_forced_replace_dialog.set_lexicon(_lexicon)
	var captured_actor := actor_public_id
	_forced_replace_dialog.open(switch_ids, func(target_public_id: String) -> void:
		_submit_command({
			"command_type": CMD_SWITCH,
			"side_id": LOCAL_PLAYER_SIDE_ID,
			"actor_public_id": captured_actor,
			"target_public_id": target_public_id,
		})
	)


func _close_forced_replace_dialog() -> void:
	if _forced_replace_dialog != null and _forced_replace_dialog.visible:
		_forced_replace_dialog.close()


# ---- Helpers ----


func _find_side(sides: Array, side_id: String) -> Dictionary:
	for raw in sides:
		if not (raw is Dictionary):
			continue
		var side: Dictionary = raw
		if str(side.get("side_id", "")) == side_id:
			return side
	return {}


func _find_opposite_side(sides: Array, side_id: String) -> Dictionary:
	for raw in sides:
		if not (raw is Dictionary):
			continue
		var side: Dictionary = raw
		if str(side.get("side_id", "")) != side_id:
			return side
	return {}


func _local_legal_action_summary() -> Dictionary:
	var turn_index: int = int(_last_snapshot.get("turn_index", -1))
	if _cached_legal_turn_index == turn_index and not _cached_legal_summary.is_empty():
		return _cached_legal_summary
	if _session == null:
		return {}
	var envelope: Dictionary = _session.legal_action_summary(LOCAL_PLAYER_SIDE_ID)
	if not bool(envelope.get("ok", false)):
		return {}
	var data = envelope.get("data", {})
	if not (data is Dictionary):
		return {}
	_cached_legal_summary = data
	_cached_legal_turn_index = turn_index
	return _cached_legal_summary


func _invalidate_legal_cache() -> void:
	_cached_legal_summary = {}
	_cached_legal_turn_index = -1


func _resolve_unit_display_name_from_snapshot(public_id: String) -> String:
	# 通过 snapshot.sides[].team_units[] 查 display_name；缺时回 public_id。
	if _last_snapshot.is_empty():
		return public_id
	for raw_side in _last_snapshot.get("sides", []):
		if not (raw_side is Dictionary):
			continue
		var unit := _view_renderer.find_unit_by_public_id(raw_side, public_id)
		if unit.is_empty():
			continue
		var display_name := str(unit.get("display_name", "")).strip_edges()
		if display_name != "":
			return display_name
		var def_id := str(unit.get("definition_id", "")).strip_edges()
		var lex_name := _view_renderer.resolve_unit_display_name_from_lexicon(def_id)
		if lex_name != "":
			return lex_name
	return public_id


# ---- Envelope / 错误 ----

func _handle_envelope(envelope: Variant) -> bool:
	if envelope == null:
		_show_toast("invalid_session", "PlayerBattleScreen received empty envelope")
		return false
	if not (envelope is Dictionary):
		_show_toast("invalid_session", "PlayerBattleScreen received invalid envelope")
		return false
	var dict: Dictionary = envelope
	if bool(dict.get("ok", false)):
		return true
	var error_code := str(dict.get("error_code", "")).strip_edges()
	var error_message := str(dict.get("error_message", "")).strip_edges()
	_show_toast(error_code, error_message)
	return false


func _show_toast(error_code: String, error_message: String) -> void:
	var toast: PlayerErrorToast = ErrorToastScene.instantiate()
	_error_toast_container.add_child(toast)
	toast.show_error(error_code, error_message)


func _exit_tree() -> void:
	if _session != null:
		var close_envelope: Dictionary = _session.close()
		if not bool(close_envelope.get("ok", false)):
			printerr("PlayerBattleScreen failed to close session: %s" % str(close_envelope.get("error_message", "")))
		_session = null
