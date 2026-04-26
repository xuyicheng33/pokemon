extends Control
class_name PlayerErrorToast

## 顶部弹出的中文错误提示。
##
## 用法：
##   var toast := PlayerErrorToastScene.instantiate()
##   add_child(toast)
##   toast.show_error("invalid_command_payload", "命令格式不正确")
##
## 内部用 Tween + Timer 自动消失；调用方不必手动 free。

const ERROR_CODE_TRANSLATIONS := {
	"invalid_command_payload": "命令格式不正确",
	"invalid_battle_runtime": "战斗运行态异常",
	"invalid_state_corruption": "战斗内部状态损坏",
	"invalid_replay_input": "回放输入非法",
	"invalid_session_request": "会话请求非法",
	"invalid_manager_request": "管理器请求非法",
	"invalid_composition": "依赖装配错误",
	"invalid_chain_depth": "效果链深超限",
	"invalid_effect_definition": "效果定义错误",
	"battle_sandbox_failed": "Sandbox 启动失败",
}

@onready var _background: ColorRect = $Background
@onready var _label: Label = $Background/Label
@onready var _timer: Timer = $Timer

var _tween: Tween = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _timer != null:
		_timer.one_shot = true
		if not _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.connect(_on_timer_timeout)


func show_error(error_code: String, error_message: String, duration_seconds: float = 3.0) -> void:
	if _label == null or _background == null:
		return
	var translated_code := _translate_code(error_code)
	var prefix := "⚠ [%s]" % translated_code
	var body := error_message if error_message != "" else translated_code
	_label.text = "%s %s" % [prefix, body]
	visible = true
	modulate = Color(1, 1, 1, 0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	if _timer != null:
		_timer.stop()
		_timer.wait_time = max(0.5, duration_seconds)
		_timer.start()


func _on_timer_timeout() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(Callable(self, "_hide_after_fade"))


func _hide_after_fade() -> void:
	visible = false


func _translate_code(error_code: String) -> String:
	var key := error_code.strip_edges().to_lower()
	if ERROR_CODE_TRANSLATIONS.has(key):
		return "错误码 %s" % key
	return "错误码 %s" % error_code
