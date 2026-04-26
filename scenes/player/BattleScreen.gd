extends Control
class_name PlayerBattleScreen

## 中文宝可梦风格三段式 BattleScreen Controller。
##
## 职责：
##   1. 启动 PlayerBattleSession（D-Session 提供）+ PlayerContentLexicon（D-Lex 提供）
##      + PlayerEventLogStreamer（D-Session 提供）。
##   2. 把 public_snapshot 渲染成 TopBar / OpponentZone / MiddleLog / PlayerZone /
##      ActionBar / Bench 等区域；按钮信号路由回 session.submit_player_command。
##   3. 终局展示 PlayerWinPanel；错误展示 PlayerErrorToast。
##
## 不直接耦合 BattleCoreManager；所有 snapshot 都从 PlayerBattleSession 拉。

const ErrorToastScene := preload("res://scenes/player/ErrorToast.tscn")
const WinPanelScene := preload("res://scenes/player/WinPanel.tscn")

# 字号常量（设计稿 CN_SMALL/MEDIUM/LARGE）
const CN_SMALL: int = 14
const CN_MEDIUM: int = 18
const CN_LARGE: int = 24

# 默认对局配置（后续可由 launch config 覆盖）
const DEFAULT_MATCHUP_ID: String = "gojo_vs_sample"
const DEFAULT_SEED: int = 9101
const LOCAL_PLAYER_SIDE_ID: String = "0"

# Stat stage 中文映射
const STAT_STAGE_LABELS := {
	"attack": "攻",
	"defense": "防",
	"sp_attack": "特攻",
	"sp_defense": "特防",
	"speed": "速",
}

# 命令类型常量（与 manager / session 协议保持一致）
const CMD_CAST: String = "cast"
const CMD_ULTIMATE: String = "ultimate"
const CMD_SWITCH: String = "switch"
const CMD_WAIT: String = "wait"
const CMD_FORCED_DEFAULT: String = "resource_forced_default"

# ---- 节点引用 ----
@onready var _turn_label: Label = $MarginContainer/VBoxContainer/TopBar/TurnLabel
@onready var _field_badge_label: Label = $MarginContainer/VBoxContainer/TopBar/FieldBadge/FieldLabel
@onready var _current_side_label: Label = $MarginContainer/VBoxContainer/TopBar/CurrentSideLabel

@onready var _opponent_card: PanelContainer = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard
@onready var _opponent_name_label: Label = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/HeaderRow/NameLabel
@onready var _opponent_combat_type_row: HBoxContainer = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/HeaderRow/CombatTypeBadgeRow
@onready var _opponent_hp_bar: ProgressBar = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/HPRow/HPBar
@onready var _opponent_hp_label: Label = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/HPRow/HPLabel
@onready var _opponent_mp_bar: ProgressBar = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/MPRow/MPBar
@onready var _opponent_mp_label: Label = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/MPRow/MPLabel
@onready var _opponent_ultimate_dots: HBoxContainer = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/UltimateDots
@onready var _opponent_stat_stages_row: HBoxContainer = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/StatStagesRow
@onready var _opponent_effects_box: VBoxContainer = $MarginContainer/VBoxContainer/OpponentZone/OpponentCard/VBox/EffectsBox
@onready var _opponent_sprite: ColorRect = $MarginContainer/VBoxContainer/OpponentZone/OpponentSprite

@onready var _opponent_bench_row: HBoxContainer = $MarginContainer/VBoxContainer/OpponentBenchRow

@onready var _log_text: PlayerLogText = $MarginContainer/VBoxContainer/MiddleLog/ScrollContainer/LogText

@onready var _player_card: PanelContainer = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard
@onready var _player_name_label: Label = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/HeaderRow/NameLabel
@onready var _player_combat_type_row: HBoxContainer = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/HeaderRow/CombatTypeBadgeRow
@onready var _player_hp_bar: ProgressBar = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/HPRow/HPBar
@onready var _player_hp_label: Label = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/HPRow/HPLabel
@onready var _player_mp_bar: ProgressBar = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/MPRow/MPBar
@onready var _player_mp_label: Label = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/MPRow/MPLabel
@onready var _player_ultimate_dots: HBoxContainer = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/UltimateDots
@onready var _player_stat_stages_row: HBoxContainer = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/StatStagesRow
@onready var _player_effects_box: VBoxContainer = $MarginContainer/VBoxContainer/PlayerZone/PlayerCard/VBox/EffectsBox
@onready var _player_sprite: ColorRect = $MarginContainer/VBoxContainer/PlayerZone/PlayerSprite

@onready var _player_bench_row: HBoxContainer = $MarginContainer/VBoxContainer/PlayerBenchRow

@onready var _action_bar: GridContainer = $MarginContainer/VBoxContainer/ActionBar
@onready var _skill_button_0: Button = $MarginContainer/VBoxContainer/ActionBar/SkillButton_0
@onready var _skill_button_1: Button = $MarginContainer/VBoxContainer/ActionBar/SkillButton_1
@onready var _skill_button_2: Button = $MarginContainer/VBoxContainer/ActionBar/SkillButton_2
@onready var _skill_button_3: Button = $MarginContainer/VBoxContainer/ActionBar/SkillButton_3
@onready var _ultimate_button: Button = $MarginContainer/VBoxContainer/ActionBar/UltimateButton
@onready var _switch_menu_button: Button = $MarginContainer/VBoxContainer/ActionBar/SwitchMenuButton
@onready var _wait_button: Button = $MarginContainer/VBoxContainer/ActionBar/WaitButton
@onready var _forced_hint_label: Label = $MarginContainer/VBoxContainer/ActionBar/ForcedHintLabel

@onready var _side_detail_panel: PanelContainer = $MarginContainer/VBoxContainer/SideDetailPanel
@onready var _error_toast_container: CanvasLayer = $ErrorToastContainer
@onready var _win_panel_container: CanvasLayer = $WinPanelContainer

# ---- 运行态 ----
var _session: Object = null  # PlayerBattleSession 实例（D-Session 提供）
var _lexicon: Object = null  # PlayerContentLexicon 实例（D-Lex 提供）
var _event_log_streamer: Object = null  # PlayerEventLogStreamer 实例（D-Session 提供）
var _last_snapshot: Dictionary = {}
var _switch_menu_popup: PopupMenu = null
var _switch_menu_options: Array = []  # 与 PopupMenu item 顺序对齐的 public_id 列表
var _skill_buttons: Array = []
var _force_run_after_idle: bool = false


func _ready() -> void:
	_skill_buttons = [_skill_button_0, _skill_button_1, _skill_button_2, _skill_button_3]
	_forced_hint_label.visible = false
	_side_detail_panel.visible = false

	_setup_log_text()
	_setup_buttons()
	_setup_switch_menu()

	_bootstrap_session()
	_refresh_ui_from_session()


# ---- 启动期 ----

func _bootstrap_session() -> void:
	# 实例化 PlayerContentLexicon（D-Lex 提供 class_name）。
	if ClassDB.class_exists("PlayerContentLexicon"):
		# 极少走到：class_name 在 GDScript 全局表里通过反射拿不到，下面的兜底才是常态。
		pass
	_lexicon = _try_new_global_class("PlayerContentLexicon")
	if _lexicon != null and _lexicon.has_method("load_all"):
		_lexicon.call("load_all")

	# 实例化 PlayerBattleSession（D-Session 提供）。
	_session = _try_new_global_class("PlayerBattleSession")
	if _session == null:
		_show_toast("invalid_composition", "PlayerBattleSession 未装配，请检查 D-Session 是否落地")
		return

	if _session.has_method("set_lexicon"):
		_session.call("set_lexicon", _lexicon)
	if _session.has_method("set_local_player_side_id"):
		_session.call("set_local_player_side_id", LOCAL_PLAYER_SIDE_ID)

	# 实例化 PlayerEventLogStreamer，注入 LogText。
	_event_log_streamer = _try_new_global_class("PlayerEventLogStreamer")
	if _event_log_streamer != null:
		if _event_log_streamer.has_method("set_log_text"):
			_event_log_streamer.call("set_log_text", _log_text)
		if _event_log_streamer.has_method("set_lexicon"):
			_event_log_streamer.call("set_lexicon", _lexicon)
	# 兜底：LogText 自己也要拿到 lexicon，便于直接 append_event。
	if _log_text != null and _log_text.has_method("set_lexicon"):
		_log_text.set_lexicon(_lexicon)

	# 启动会话。
	if _session.has_method("start_session"):
		var start_envelope: Variant = _session.call(
			"start_session",
			{
				"matchup_id": DEFAULT_MATCHUP_ID,
				"seed": DEFAULT_SEED,
				"local_player_side_id": LOCAL_PLAYER_SIDE_ID,
			}
		)
		_handle_envelope(start_envelope)


func _setup_log_text() -> void:
	if _log_text == null:
		return
	# LogText.gd 的 _ready 已强制 bbcode + scroll_following，这里仅做初始 clear。
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


func _setup_switch_menu() -> void:
	_switch_menu_popup = PopupMenu.new()
	_switch_menu_popup.name = "SwitchMenuPopup"
	_switch_menu_popup.id_pressed.connect(_on_switch_menu_item_selected)
	add_child(_switch_menu_popup)


# ---- 按钮回调 ----

func _on_skill_button_pressed(index: int) -> void:
	var legal: Dictionary = _local_legal_action_set()
	var legal_skill_ids: Array = legal.get("legal_skill_ids", [])
	if index < 0 or index >= legal_skill_ids.size():
		return
	var skill_id: String = str(legal_skill_ids[index])
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	_submit_command({
		"command_type": CMD_CAST,
		"actor_public_id": actor_public_id,
		"skill_id": skill_id,
	})


func _on_ultimate_pressed() -> void:
	var legal: Dictionary = _local_legal_action_set()
	var legal_ultimate_ids: Array = legal.get("legal_ultimate_ids", [])
	if legal_ultimate_ids.is_empty():
		return
	var ultimate_id: String = str(legal_ultimate_ids[0])
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	_submit_command({
		"command_type": CMD_ULTIMATE,
		"actor_public_id": actor_public_id,
		"skill_id": ultimate_id,
	})


func _on_switch_menu_pressed() -> void:
	var legal: Dictionary = _local_legal_action_set()
	var switch_ids: Array = legal.get("legal_switch_target_public_ids", [])
	if switch_ids.is_empty():
		return
	_switch_menu_popup.clear()
	_switch_menu_options.clear()
	for raw_id in switch_ids:
		var public_id := str(raw_id)
		var display_name := _resolve_unit_display_name(public_id)
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
	var legal: Dictionary = _local_legal_action_set()
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	_submit_command({
		"command_type": CMD_SWITCH,
		"actor_public_id": actor_public_id,
		"target_public_id": target_public_id,
	})


func _on_wait_pressed() -> void:
	var legal: Dictionary = _local_legal_action_set()
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	_submit_command({
		"command_type": CMD_WAIT,
		"actor_public_id": actor_public_id,
	})


# ---- 命令提交 / 推进 ----

func _submit_command(payload: Dictionary) -> void:
	if _session == null:
		return
	if not _session.has_method("submit_player_command"):
		_show_toast("invalid_composition", "PlayerBattleSession.submit_player_command 缺失")
		return
	var envelope: Variant = _session.call("submit_player_command", payload)
	if not _handle_envelope(envelope):
		_refresh_ui_from_session()
		return
	# P2 由 PlayerDefaultPolicy 自动出招；推进一回合后刷 UI。
	_advance_one_turn()
	_refresh_ui_from_session()


func _advance_one_turn() -> void:
	if _session == null or not _session.has_method("run_turn"):
		return
	var envelope: Variant = _session.call("run_turn")
	_handle_envelope(envelope)


func _refresh_ui_from_session() -> void:
	if _session == null or not _session.has_method("get_public_snapshot"):
		return
	var snapshot_variant: Variant = _session.call("get_public_snapshot")
	if typeof(snapshot_variant) != TYPE_DICTIONARY:
		return
	var snapshot: Dictionary = snapshot_variant
	_last_snapshot = snapshot
	_refresh_ui(snapshot)


# ---- UI 刷新 ----

func _refresh_ui(snapshot: Dictionary) -> void:
	_refresh_top_bar(snapshot)
	var sides: Array = snapshot.get("sides", [])
	var local_side: Dictionary = _find_side(sides, LOCAL_PLAYER_SIDE_ID)
	var opponent_side: Dictionary = _find_opposite_side(sides, LOCAL_PLAYER_SIDE_ID)

	_refresh_card(opponent_side, _opponent_name_label, _opponent_combat_type_row,
		_opponent_hp_bar, _opponent_hp_label, _opponent_mp_bar, _opponent_mp_label,
		_opponent_ultimate_dots, _opponent_stat_stages_row, _opponent_effects_box,
		_opponent_sprite)
	_refresh_card(local_side, _player_name_label, _player_combat_type_row,
		_player_hp_bar, _player_hp_label, _player_mp_bar, _player_mp_label,
		_player_ultimate_dots, _player_stat_stages_row, _player_effects_box,
		_player_sprite)

	_refresh_bench(_opponent_bench_row, opponent_side)
	_refresh_bench(_player_bench_row, local_side)

	_refresh_action_bar(snapshot)
	_refresh_event_log(snapshot)
	_refresh_battle_result(snapshot)


func _refresh_top_bar(snapshot: Dictionary) -> void:
	var turn_index: int = int(snapshot.get("turn_index", 1))
	_turn_label.text = "回合 %d" % max(1, turn_index)
	var field_dict: Dictionary = snapshot.get("field", {}) if snapshot.get("field", null) is Dictionary else {}
	var field_id: String = str(snapshot.get("field_id", "")).strip_edges()
	if field_dict.is_empty() and field_id == "":
		_field_badge_label.text = "场地: 无"
	else:
		var fid := field_id if field_id != "" else str(field_dict.get("field_id", ""))
		var field_name := _resolve_field_display_name(fid)
		var remaining := int(field_dict.get("remaining", field_dict.get("remaining_turns", -1)))
		if remaining >= 0:
			_field_badge_label.text = "场地: %s（剩 %d 回合）" % [field_name, remaining]
		else:
			_field_badge_label.text = "场地: %s" % field_name

	var current_side: String = str(snapshot.get("current_side_to_select", "")).strip_edges()
	if current_side == "":
		_current_side_label.text = ""
	elif current_side == LOCAL_PLAYER_SIDE_ID:
		_current_side_label.text = "请选择你的指令"
	else:
		_current_side_label.text = "等待 P%s 选择" % current_side


func _refresh_card(
	side: Dictionary,
	name_label: Label,
	combat_type_row: HBoxContainer,
	hp_bar: ProgressBar,
	hp_label: Label,
	mp_bar: ProgressBar,
	mp_label: Label,
	ultimate_dots: HBoxContainer,
	stat_stages_row: HBoxContainer,
	effects_box: VBoxContainer,
	sprite: ColorRect
) -> void:
	var active: Dictionary = side.get("active", {}) if side.get("active", null) is Dictionary else {}
	var public_id := str(active.get("public_id", ""))
	var definition_id := str(active.get("definition_id", ""))
	var display_name := str(active.get("display_name", "")).strip_edges()
	if display_name == "" and public_id != "":
		display_name = _resolve_unit_display_name(public_id)
	if display_name == "":
		display_name = definition_id
	name_label.text = display_name if display_name != "" else "（空）"

	# 属性条
	_clear_children(combat_type_row)
	for ct in active.get("combat_type_ids", []):
		var ct_id := str(ct).strip_edges()
		if ct_id == "":
			continue
		var badge := Label.new()
		badge.text = _resolve_combat_type_display_name(ct_id)
		badge.add_theme_font_size_override("font_size", CN_SMALL)
		badge.add_theme_color_override("font_color", _resolve_combat_type_color(ct_id))
		combat_type_row.add_child(badge)

	# HP / MP
	var current_hp := int(active.get("current_hp", 0))
	var max_hp := max(1, int(active.get("max_hp", 1)))
	hp_bar.max_value = 100.0
	hp_bar.value = clamp(float(current_hp) / float(max_hp) * 100.0, 0.0, 100.0)
	hp_label.text = "%d/%d" % [current_hp, max_hp]

	var current_mp := int(active.get("current_mp", 0))
	var max_mp := max(1, int(active.get("max_mp", 1)))
	mp_bar.max_value = 100.0
	mp_bar.value = clamp(float(current_mp) / float(max_mp) * 100.0, 0.0, 100.0)
	mp_label.text = "%d/%d" % [current_mp, max_mp]

	# 奥义点圆点
	var points := int(active.get("ultimate_points", 0))
	var required := int(active.get("ultimate_points_required", 0))
	var cap := int(active.get("ultimate_points_cap", required))
	_render_ultimate_dots(ultimate_dots, points, required, cap)

	# Stat stages
	_clear_children(stat_stages_row)
	var stat_stages: Dictionary = active.get("stat_stages", {}) if active.get("stat_stages", null) is Dictionary else {}
	var keys := STAT_STAGE_LABELS.keys()
	for stat_key in keys:
		var stage := int(stat_stages.get(stat_key, 0))
		if stage == 0:
			continue
		var label := Label.new()
		label.text = "%s %s%d" % [STAT_STAGE_LABELS[stat_key], "+" if stage > 0 else "", stage]
		label.add_theme_font_size_override("font_size", CN_SMALL)
		stat_stages_row.add_child(label)

	# Effects
	_clear_children(effects_box)
	for raw_effect in active.get("effects", []):
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect
		var def_id := str(effect.get("effect_definition_id", "")).strip_edges()
		if def_id == "":
			continue
		var remaining := int(effect.get("remaining", -1))
		var effect_name := _resolve_effect_display_name(def_id)
		var line := Label.new()
		if remaining > 0:
			line.text = "%s（剩 %d 回合）" % [effect_name, remaining]
		else:
			line.text = effect_name
		line.add_theme_font_size_override("font_size", CN_SMALL)
		effects_box.add_child(line)

	# Sprite 占位色块
	var primary_type := ""
	var combat_type_ids: Array = active.get("combat_type_ids", [])
	if not combat_type_ids.is_empty():
		primary_type = str(combat_type_ids[0])
	if sprite != null:
		sprite.color = _resolve_combat_type_color(primary_type)


func _refresh_bench(bench_row: HBoxContainer, side: Dictionary) -> void:
	_clear_children(bench_row)
	var bench: Array = side.get("bench", []) if side.get("bench", null) is Array else []
	for raw_unit in bench:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(140, 56)
		bench_row.add_child(slot)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		slot.add_child(vbox)
		if not (raw_unit is Dictionary):
			var x_label := Label.new()
			x_label.text = "X"
			x_label.add_theme_font_size_override("font_size", CN_MEDIUM)
			vbox.add_child(x_label)
			continue
		var unit: Dictionary = raw_unit
		var public_id := str(unit.get("public_id", ""))
		var current_hp := int(unit.get("current_hp", 0))
		var max_hp := max(1, int(unit.get("max_hp", 1)))
		var leave_state := str(unit.get("leave_state", "")).strip_edges().to_lower()
		var fainted := current_hp <= 0 or leave_state == "fainted" or leave_state == "fainted_pending_leave"
		var name_label := Label.new()
		var display_name := _resolve_unit_display_name(public_id)
		name_label.text = "%s（%s）" % [display_name, public_id] if display_name != public_id else public_id
		name_label.add_theme_font_size_override("font_size", CN_SMALL)
		vbox.add_child(name_label)
		if fainted:
			var x_label2 := Label.new()
			x_label2.text = "X 倒下"
			x_label2.add_theme_font_size_override("font_size", CN_SMALL)
			vbox.add_child(x_label2)
		else:
			var hp_bar := ProgressBar.new()
			hp_bar.max_value = 100.0
			hp_bar.value = clamp(float(current_hp) / float(max_hp) * 100.0, 0.0, 100.0)
			hp_bar.show_percentage = false
			hp_bar.custom_minimum_size = Vector2(120, 8)
			vbox.add_child(hp_bar)
			var hp_label := Label.new()
			hp_label.text = "%d/%d" % [current_hp, max_hp]
			hp_label.add_theme_font_size_override("font_size", CN_SMALL)
			vbox.add_child(hp_label)


func _refresh_action_bar(snapshot: Dictionary) -> void:
	var legal: Dictionary = _local_legal_action_set(snapshot)
	var legal_skill_ids: Array = legal.get("legal_skill_ids", [])
	var legal_ultimate_ids: Array = legal.get("legal_ultimate_ids", [])
	var switch_ids: Array = legal.get("legal_switch_target_public_ids", [])
	var wait_allowed: bool = bool(legal.get("wait_allowed", false))
	var forced_command_type: String = str(legal.get("forced_command_type", "")).strip_edges()
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	var actor_unit: Dictionary = _find_unit_in_snapshot(snapshot, actor_public_id)

	# Skill buttons
	for i in _skill_buttons.size():
		var button: Button = _skill_buttons[i]
		if button == null:
			continue
		if i < legal_skill_ids.size():
			var skill_id := str(legal_skill_ids[i])
			button.text = "%s · %dMP" % [_resolve_skill_display_name(skill_id), _resolve_skill_mp_cost(skill_id, actor_unit)]
			button.disabled = false
		else:
			button.text = "—"
			button.disabled = true

	# Ultimate
	if legal_ultimate_ids.is_empty():
		var ultimate_def_id := _resolve_unit_ultimate_skill_id(actor_unit)
		if ultimate_def_id != "":
			_ultimate_button.text = "奥义 %s" % _resolve_skill_display_name(ultimate_def_id)
		else:
			_ultimate_button.text = "奥义 —"
		_ultimate_button.disabled = true
	else:
		var first_ult := str(legal_ultimate_ids[0])
		var ult_name := _resolve_skill_display_name(first_ult)
		var points := int(actor_unit.get("ultimate_points", 0))
		var required := int(actor_unit.get("ultimate_points_required", 0))
		var prefix := "奥义 %s" % ult_name
		if required > 0 and points >= required:
			_ultimate_button.text = "%s 满" % prefix
		else:
			_ultimate_button.text = prefix
		_ultimate_button.disabled = false

	# Switch
	_switch_menu_button.text = "换人 ▼"
	_switch_menu_button.disabled = switch_ids.is_empty()

	# Wait
	_wait_button.text = "等待"
	_wait_button.disabled = not wait_allowed

	# Forced default
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
		if not _force_run_after_idle:
			_force_run_after_idle = true
			call_deferred("_force_run_default_then_refresh")
	else:
		_forced_hint_label.visible = false


func _force_run_default_then_refresh() -> void:
	_force_run_after_idle = false
	if _session == null:
		return
	var legal: Dictionary = _local_legal_action_set()
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	if _session.has_method("submit_player_command"):
		_session.call("submit_player_command", {
			"command_type": CMD_FORCED_DEFAULT,
			"actor_public_id": actor_public_id,
		})
	_advance_one_turn()
	_refresh_ui_from_session()


func _refresh_event_log(snapshot: Dictionary) -> void:
	# 优先走 PlayerEventLogStreamer.consume_into_log_text(snapshot)。
	if _event_log_streamer != null and _event_log_streamer.has_method("consume_into_log_text"):
		_event_log_streamer.call("consume_into_log_text", snapshot, _log_text)
		return
	if _event_log_streamer != null and _event_log_streamer.has_method("consume"):
		_event_log_streamer.call("consume", snapshot)
		return
	# 兜底：直接逐条 append。
	if _log_text == null:
		return
	for raw_event in snapshot.get("events", []):
		if raw_event is Dictionary:
			_log_text.append_event(raw_event)


func _refresh_battle_result(snapshot: Dictionary) -> void:
	var battle_result = snapshot.get("battle_result", null)
	if not (battle_result is Dictionary):
		return
	var result_dict: Dictionary = battle_result
	if not bool(result_dict.get("finished", false)):
		return
	# 保护：只展示一次 WinPanel
	if _win_panel_container.get_child_count() > 0:
		return
	var panel: PlayerWinPanel = WinPanelScene.instantiate()
	_win_panel_container.add_child(panel)
	panel.set_local_player_side_id(LOCAL_PLAYER_SIDE_ID)
	var winner_side_id = result_dict.get("winner_side_id", null)
	var result_type := str(result_dict.get("result_type", "")).strip_edges()
	var reason := str(result_dict.get("reason", "")).strip_edges()
	panel.show_outcome(winner_side_id, result_type, reason)


# ---- Helpers ----

func _render_ultimate_dots(container: HBoxContainer, points: int, required: int, cap: int) -> void:
	_clear_children(container)
	var total := max(cap, max(required, 1))
	for i in total:
		if required > 0 and i == required:
			var sep := VSeparator.new()
			container.add_child(sep)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = Color(0.95, 0.85, 0.25) if i < points else Color(0.25, 0.25, 0.30)
		container.add_child(dot)


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()


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


func _find_unit_in_snapshot(snapshot: Dictionary, public_id: String) -> Dictionary:
	if public_id == "":
		return {}
	for raw_side in snapshot.get("sides", []):
		if not (raw_side is Dictionary):
			continue
		var side: Dictionary = raw_side
		for raw_unit in side.get("team_units", []):
			if raw_unit is Dictionary and str(raw_unit.get("public_id", "")) == public_id:
				return raw_unit
		var active: Dictionary = side.get("active", {}) if side.get("active", null) is Dictionary else {}
		if str(active.get("public_id", "")) == public_id:
			return active
	return {}


func _local_legal_action_set(snapshot: Variant = null) -> Dictionary:
	var snap: Dictionary = _last_snapshot
	if snapshot is Dictionary:
		snap = snapshot
	var by_side = snap.get("legal_actions_by_side", {})
	if by_side is Dictionary and by_side.has(LOCAL_PLAYER_SIDE_ID):
		var entry = by_side[LOCAL_PLAYER_SIDE_ID]
		if entry is Dictionary:
			return entry
	# 走 session 直接拉
	if _session != null and _session.has_method("get_legal_action_set"):
		var fresh = _session.call("get_legal_action_set", LOCAL_PLAYER_SIDE_ID)
		if fresh is Dictionary:
			return fresh
	return {}


func _resolve_unit_display_name(public_id: String) -> String:
	if _lexicon != null and _lexicon.has_method("translate_unit_public_id"):
		var result = _lexicon.call("translate_unit_public_id", public_id)
		if typeof(result) == TYPE_STRING and result != "":
			return result
	return public_id


func _resolve_skill_display_name(skill_id: String) -> String:
	if _lexicon != null and _lexicon.has_method("translate_skill_id"):
		var result = _lexicon.call("translate_skill_id", skill_id)
		if typeof(result) == TYPE_STRING and result != "":
			return result
	return skill_id


func _resolve_effect_display_name(def_id: String) -> String:
	if _lexicon != null and _lexicon.has_method("translate_effect_definition_id"):
		var result = _lexicon.call("translate_effect_definition_id", def_id)
		if typeof(result) == TYPE_STRING and result != "":
			return result
	return def_id


func _resolve_field_display_name(field_id: String) -> String:
	if field_id == "":
		return "无"
	if _lexicon != null and _lexicon.has_method("translate_field_id"):
		var result = _lexicon.call("translate_field_id", field_id)
		if typeof(result) == TYPE_STRING and result != "":
			return result
	return field_id


func _resolve_combat_type_display_name(combat_type_id: String) -> String:
	if combat_type_id == "":
		return ""
	if _lexicon != null and _lexicon.has_method("translate_combat_type_id"):
		var result = _lexicon.call("translate_combat_type_id", combat_type_id)
		if typeof(result) == TYPE_STRING and result != "":
			return result
	return combat_type_id


func _resolve_combat_type_color(combat_type_id: String) -> Color:
	if _lexicon != null and _lexicon.has_method("combat_type_color"):
		var result = _lexicon.call("combat_type_color", combat_type_id)
		if result is Color:
			return result
	return _hash_color(combat_type_id)


func _hash_color(seed_str: String) -> Color:
	if seed_str == "":
		return Color(0.45, 0.45, 0.50)
	var palette := [
		Color(0.85, 0.30, 0.25),
		Color(0.25, 0.55, 0.85),
		Color(0.40, 0.75, 0.35),
		Color(0.85, 0.70, 0.25),
		Color(0.65, 0.40, 0.85),
		Color(0.35, 0.75, 0.85),
	]
	var idx := absi(seed_str.hash()) % palette.size()
	return palette[idx]


func _resolve_skill_mp_cost(skill_id: String, actor_unit: Dictionary) -> int:
	# 优先从 active.skill_costs / .skills 中读；不存在则委托 lexicon。
	for key in ["skill_costs", "skills", "skill_loadout"]:
		var bag: Variant = actor_unit.get(key, null)
		if bag is Dictionary and bag.has(skill_id):
			var entry = bag[skill_id]
			if entry is Dictionary:
				return int(entry.get("mp_cost", 0))
			return int(entry)
		if bag is Array:
			for raw in bag:
				if raw is Dictionary and str(raw.get("skill_id", "")) == skill_id:
					return int(raw.get("mp_cost", 0))
	if _lexicon != null and _lexicon.has_method("skill_mp_cost"):
		var result = _lexicon.call("skill_mp_cost", skill_id)
		if typeof(result) == TYPE_INT:
			return int(result)
	return 0


func _resolve_unit_ultimate_skill_id(unit: Dictionary) -> String:
	for key in ["ultimate_skill_id", "ultimate_id"]:
		var v = unit.get(key, "")
		if typeof(v) == TYPE_STRING and v != "":
			return str(v)
	return ""


func _try_new_global_class(class_name_str: String) -> Object:
	# Godot 4 GDScript：类名注册到 ProjectSettings 后可通过 ClassDB 找到 nativeness，但
	# 自定义 class_name 只能用 ResourceLoader 加载脚本路径。这里通过反射尝试，找不到回 null。
	if Engine.has_singleton(class_name_str):
		return Engine.get_singleton(class_name_str) as Object
	# 最后兜底：直接 new() 拼接 class 名走全局名查找
	var global_classes := ProjectSettings.get_setting("_global_script_classes", [])
	if global_classes is Array:
		for entry in global_classes:
			if entry is Dictionary and str(entry.get("class", "")) == class_name_str:
				var script_path := str(entry.get("path", ""))
				if script_path == "":
					return null
				var script := load(script_path)
				if script is GDScript:
					return script.new()
	return null


# ---- Envelope / 错误 ----

func _handle_envelope(envelope: Variant) -> bool:
	if envelope == null:
		return true
	if not (envelope is Dictionary):
		return true
	var dict: Dictionary = envelope
	if bool(dict.get("ok", true)):
		return true
	var error_code := str(dict.get("error_code", "")).strip_edges()
	var error_message := str(dict.get("error_message", "")).strip_edges()
	_show_toast(error_code, error_message)
	return false


func _show_toast(error_code: String, error_message: String) -> void:
	var toast: PlayerErrorToast = ErrorToastScene.instantiate()
	_error_toast_container.add_child(toast)
	toast.show_error(error_code, error_message)
