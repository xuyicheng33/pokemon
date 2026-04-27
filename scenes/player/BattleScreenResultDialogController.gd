extends RefCounted
class_name PlayerBattleScreenResultDialogController

const WinPanelScene := preload("res://scenes/player/WinPanel.tscn")
const ForcedReplaceDialogScene := preload("res://scenes/player/ForcedReplaceDialog.tscn")

var _win_panel_container: CanvasLayer = null
var _dialog_container: CanvasLayer = null
var _lexicon: PlayerContentLexicon = null
var _local_player_side_id: String = ""
var _submit_switch_callback: Callable = Callable()
var _menu_callback: Callable = Callable()
var _forced_replace_dialog: PlayerForcedReplaceDialog = null
var _win_panel_shown: bool = false


func setup(win_panel_container: CanvasLayer, dialog_container: CanvasLayer, lexicon: PlayerContentLexicon,
		local_player_side_id: String, submit_switch_callback: Callable, menu_callback: Callable) -> void:
	_win_panel_container = win_panel_container
	_dialog_container = dialog_container
	_lexicon = lexicon
	_local_player_side_id = local_player_side_id
	_submit_switch_callback = submit_switch_callback
	_menu_callback = menu_callback


func clear() -> void:
	_win_panel_shown = false
	_forced_replace_dialog = null
	_clear_container_children(_win_panel_container)
	_clear_container_children(_dialog_container)


func refresh_battle_result(snapshot: Dictionary) -> void:
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
	panel.set_local_player_side_id(_local_player_side_id)
	if _menu_callback.is_valid() and not panel.menu_requested.is_connected(_menu_callback):
		panel.menu_requested.connect(_menu_callback)
	var winner_side_id = result_dict.get("winner_side_id", null)
	var result_type := str(result_dict.get("result_type", "")).strip_edges()
	var reason := str(result_dict.get("reason", "")).strip_edges()
	panel.show_outcome(winner_side_id, result_type, reason)


func open_forced_replace_dialog(switch_ids: Array, actor_public_id: String) -> void:
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
		if _submit_switch_callback.is_valid():
			_submit_switch_callback.call(captured_actor, target_public_id)
	)


func close_forced_replace_dialog() -> void:
	if _forced_replace_dialog != null and _forced_replace_dialog.visible:
		_forced_replace_dialog.close()


func _clear_container_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
