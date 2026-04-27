extends RefCounted
class_name PlayerBattleScreenActionBarController

const CMD_CAST: String = "skill"
const CMD_ULTIMATE: String = "ultimate"
const CMD_SWITCH: String = "switch"
const CMD_WAIT: String = "wait"
const CMD_FORCED_DEFAULT: String = "resource_forced_default"

var _view_renderer: PlayerBattleScreenViewRenderer = null
var _skill_buttons: Array = []
var _ultimate_button: Button = null
var _switch_menu_button: Button = null
var _wait_button: Button = null
var _forced_hint_label: Label = null
var _switch_menu_popup: PopupMenu = null
var _switch_menu_options: Array = []
var _switch_selected_callback: Callable = Callable()


func setup(view_renderer: PlayerBattleScreenViewRenderer, skill_buttons: Array, ultimate_button: Button,
		switch_menu_button: Button, wait_button: Button, forced_hint_label: Label, owner: Node,
		switch_selected_callback: Callable) -> void:
	_view_renderer = view_renderer
	_skill_buttons = skill_buttons
	_ultimate_button = ultimate_button
	_switch_menu_button = switch_menu_button
	_wait_button = wait_button
	_forced_hint_label = forced_hint_label
	_switch_selected_callback = switch_selected_callback
	if _forced_hint_label != null:
		_forced_hint_label.visible = false
	_switch_menu_popup = PopupMenu.new()
	_switch_menu_popup.name = "SwitchMenuPopup"
	_switch_menu_popup.id_pressed.connect(_on_switch_menu_item_selected)
	owner.add_child(_switch_menu_popup)


func connect_buttons(skill_callback: Callable, ultimate_callback: Callable,
		switch_menu_callback: Callable, wait_callback: Callable) -> void:
	for i in _skill_buttons.size():
		var button: Button = _skill_buttons[i]
		if button == null:
			continue
		var index: int = i
		button.pressed.connect(func() -> void: skill_callback.call(index))
	_ultimate_button.pressed.connect(ultimate_callback)
	_switch_menu_button.pressed.connect(switch_menu_callback)
	_wait_button.pressed.connect(wait_callback)


func clear() -> void:
	if _switch_menu_popup != null:
		_switch_menu_popup.hide()
		_switch_menu_popup.clear()
	_switch_menu_options.clear()
	if _forced_hint_label != null:
		_forced_hint_label.visible = false


func switch_menu_popup() -> PopupMenu:
	return _switch_menu_popup


func switch_menu_options() -> Array:
	return _switch_menu_options.duplicate()


func refresh(legal: Dictionary, local_side: Dictionary, battle_finished: bool, our_turn: bool) -> Dictionary:
	var legal_skill_ids: Array = legal.get("legal_skill_ids", [])
	var legal_ultimate_ids: Array = legal.get("legal_ultimate_ids", [])
	var switch_ids: Array = legal.get("legal_switch_target_public_ids", [])
	var wait_allowed: bool = bool(legal.get("wait_allowed", false))
	var forced_command_type: String = str(legal.get("forced_command_type", "")).strip_edges()
	var actor_public_id: String = str(legal.get("actor_public_id", ""))
	var actor_unit: Dictionary = _view_renderer.find_unit_by_public_id(local_side, actor_public_id)

	_refresh_skill_buttons(legal_skill_ids, our_turn)
	_refresh_ultimate_button(legal_ultimate_ids, actor_unit, our_turn)
	_refresh_basic_buttons(switch_ids, wait_allowed, our_turn)
	var force_run_requested := _refresh_forced_default_state(forced_command_type, battle_finished)
	var must_replace := _must_open_forced_replace(
		our_turn,
		forced_command_type,
		legal_skill_ids,
		legal_ultimate_ids,
		wait_allowed,
		switch_ids
	)
	return {
		"force_run_default": force_run_requested,
		"must_replace": must_replace,
		"switch_ids": switch_ids,
		"actor_public_id": actor_public_id,
	}


func open_switch_menu(legal: Dictionary, display_name_resolver: Callable) -> void:
	var switch_ids: Array = legal.get("legal_switch_target_public_ids", [])
	if switch_ids.is_empty() or _switch_menu_popup == null:
		return
	_switch_menu_popup.clear()
	_switch_menu_options.clear()
	for raw_id in switch_ids:
		var public_id := str(raw_id)
		var display_name := public_id
		if display_name_resolver.is_valid():
			display_name = str(display_name_resolver.call(public_id))
		var label := "%s（%s）" % [display_name, public_id] if display_name != public_id else public_id
		_switch_menu_options.append(public_id)
		_switch_menu_popup.add_item(label, _switch_menu_options.size() - 1)
	var pos := _switch_menu_button.global_position + Vector2(0, _switch_menu_button.size.y)
	_switch_menu_popup.position = Vector2i(int(pos.x), int(pos.y))
	_switch_menu_popup.size = Vector2i(220, 0)
	_switch_menu_popup.popup()


func build_skill_payload(side_id: String, legal: Dictionary, index: int) -> Dictionary:
	var legal_skill_ids: Array = legal.get("legal_skill_ids", [])
	if index < 0 or index >= legal_skill_ids.size():
		return {}
	return {
		"command_type": CMD_CAST,
		"side_id": side_id,
		"actor_public_id": str(legal.get("actor_public_id", "")),
		"skill_id": str(legal_skill_ids[index]),
	}


func build_ultimate_payload(side_id: String, legal: Dictionary) -> Dictionary:
	var legal_ultimate_ids: Array = legal.get("legal_ultimate_ids", [])
	if legal_ultimate_ids.is_empty():
		return {}
	return {
		"command_type": CMD_ULTIMATE,
		"side_id": side_id,
		"actor_public_id": str(legal.get("actor_public_id", "")),
		"skill_id": str(legal_ultimate_ids[0]),
	}


func build_switch_payload(side_id: String, legal: Dictionary, target_public_id: String) -> Dictionary:
	return {
		"command_type": CMD_SWITCH,
		"side_id": side_id,
		"actor_public_id": str(legal.get("actor_public_id", "")),
		"target_public_id": target_public_id,
	}


func build_forced_switch_payload(side_id: String, actor_public_id: String, target_public_id: String) -> Dictionary:
	return {
		"command_type": CMD_SWITCH,
		"side_id": side_id,
		"actor_public_id": actor_public_id,
		"target_public_id": target_public_id,
	}


func build_wait_payload(side_id: String, legal: Dictionary) -> Dictionary:
	return {
		"command_type": CMD_WAIT,
		"side_id": side_id,
		"actor_public_id": str(legal.get("actor_public_id", "")),
	}


func _refresh_skill_buttons(legal_skill_ids: Array, our_turn: bool) -> void:
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


func _refresh_ultimate_button(legal_ultimate_ids: Array, actor_unit: Dictionary, our_turn: bool) -> void:
	if legal_ultimate_ids.is_empty():
		_ultimate_button.text = "奥义 —"
		_ultimate_button.disabled = true
		return
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


func _refresh_basic_buttons(switch_ids: Array, wait_allowed: bool, our_turn: bool) -> void:
	_switch_menu_button.text = "换人 ▼"
	_switch_menu_button.disabled = switch_ids.is_empty() or not our_turn
	_wait_button.text = "等待"
	_wait_button.disabled = (not wait_allowed) or (not our_turn)


func _refresh_forced_default_state(forced_command_type: String, battle_finished: bool) -> bool:
	if forced_command_type != CMD_FORCED_DEFAULT:
		_forced_hint_label.visible = false
		return false
	_forced_hint_label.visible = true
	_forced_hint_label.text = "无可用主动技能，将自动反伤"
	for button in _skill_buttons:
		if button != null:
			button.disabled = true
	_ultimate_button.disabled = true
	_switch_menu_button.disabled = true
	_wait_button.disabled = true
	return not battle_finished


func _must_open_forced_replace(our_turn: bool, forced_command_type: String, legal_skill_ids: Array,
		legal_ultimate_ids: Array, wait_allowed: bool, switch_ids: Array) -> bool:
	return our_turn \
		and forced_command_type == "" \
		and legal_skill_ids.is_empty() \
		and legal_ultimate_ids.is_empty() \
		and not wait_allowed \
		and not switch_ids.is_empty()


func _on_switch_menu_item_selected(item_index: int) -> void:
	if item_index < 0 or item_index >= _switch_menu_options.size():
		return
	if _switch_selected_callback.is_valid():
		_switch_selected_callback.call(str(_switch_menu_options[item_index]))
