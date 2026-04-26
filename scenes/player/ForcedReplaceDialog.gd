extends Control
class_name PlayerForcedReplaceDialog

## 强制换人对话框。
##
## 用法：
##   dialog.set_lexicon(player_content_lexicon)  # 可选
##   dialog.open(["sukuna#1", "kashimo#1"], func(public_id): print(public_id))

@onready var _list_container: VBoxContainer = $Center/Panel/VBox/ListContainer
@onready var _title_label: Label = $Center/Panel/VBox/TitleLabel

var _on_select: Callable = Callable()
var _lexicon: Object = null


func _ready() -> void:
	visible = false
	if _title_label != null:
		_title_label.text = "你的角色已倒下，请选择替补："


## 注入 PlayerContentLexicon（可选）。null 时显示 public_id 原值。
func set_lexicon(lexicon: Object) -> void:
	_lexicon = lexicon


func open(legal_switch_unit_ids: Array, on_select: Callable) -> void:
	_on_select = on_select
	_clear_list()
	if _list_container == null:
		return
	for raw_id in legal_switch_unit_ids:
		var public_id := str(raw_id)
		var display_name := _resolve_display_name(public_id)
		var button := Button.new()
		button.text = "%s（%s）" % [display_name, public_id] if display_name != public_id else public_id
		button.custom_minimum_size = Vector2(280, 40)
		var captured_id := public_id
		button.pressed.connect(func() -> void: _on_button_pressed(captured_id))
		_list_container.add_child(button)
	visible = true


func close() -> void:
	visible = false
	_clear_list()
	_on_select = Callable()


func _on_button_pressed(public_id: String) -> void:
	var callable := _on_select
	close()
	if callable.is_valid():
		callable.call(public_id)


func _clear_list() -> void:
	if _list_container == null:
		return
	for child in _list_container.get_children():
		child.queue_free()


func _resolve_display_name(public_id: String) -> String:
	if _lexicon == null:
		return public_id
	if _lexicon.has_method("translate_unit_public_id"):
		var result: Variant = _lexicon.call("translate_unit_public_id", public_id)
		if typeof(result) == TYPE_STRING and result != "":
			return result
	return public_id
