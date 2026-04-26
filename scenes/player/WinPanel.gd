extends Control
class_name PlayerWinPanel

## 居中显示胜负画面。
##
## 用法：
##   panel.show_outcome(0, "win", "elimination")
##   panel.show_outcome(1, "win", "surrender")
##   panel.show_outcome(null, "draw", "")
##   panel.show_outcome(null, "no_winner", "invalid_state_corruption")
##
## 提供"返回菜单"按钮信号 menu_requested。

signal menu_requested

const RESULT_TRANSLATIONS := {
	"elimination": "全队倒下",
	"turn_limit": "回合超时",
	"surrender": "投降",
	"invalid_state_corruption": "战斗异常终止",
	"invalid_runtime": "战斗运行态异常",
	"max_chain_depth": "效果链深超限",
}

@onready var _title_label: Label = $Center/Panel/VBox/TitleLabel
@onready var _reason_label: Label = $Center/Panel/VBox/ReasonLabel
@onready var _menu_button: Button = $Center/Panel/VBox/MenuButton

var _local_player_side_id: Variant = 0


func _ready() -> void:
	visible = false
	if _menu_button != null and not _menu_button.pressed.is_connected(_on_menu_pressed):
		_menu_button.pressed.connect(_on_menu_pressed)


func set_local_player_side_id(side_id: Variant) -> void:
	_local_player_side_id = side_id


func show_outcome(winner_side_id: Variant, result_type: String, reason: String) -> void:
	if _title_label == null or _reason_label == null:
		return
	_title_label.text = _format_title(winner_side_id, result_type)
	_reason_label.text = _format_reason(reason)
	visible = true


func _format_title(winner_side_id: Variant, result_type: String) -> String:
	var rt := result_type.strip_edges().to_lower()
	match rt:
		"win":
			if _local_player_side_id != null and winner_side_id != null and str(winner_side_id) == str(_local_player_side_id):
				return "胜利！"
			return "败北！"
		"draw":
			return "平局"
		"no_winner":
			return "无效战斗"
		_:
			return "战斗结束"


func _format_reason(reason: String) -> String:
	var key := reason.strip_edges().to_lower()
	if key == "":
		return ""
	if RESULT_TRANSLATIONS.has(key):
		return "原因：%s" % RESULT_TRANSLATIONS[key]
	return "原因：%s" % reason


func _on_menu_pressed() -> void:
	emit_signal("menu_requested")
