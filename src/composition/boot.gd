extends Node
class_name Boot

const PLAYER_LAUNCH_CONFIG := "player_mvp"
const SANDBOX_LAUNCH_CONFIG := "sandbox"

@export var launch_config: String = SANDBOX_LAUNCH_CONFIG  # 默认走 sandbox 不影响测试基线

func _ready() -> void:
	call_deferred("_open")

func _open() -> void:
	match launch_config:
		PLAYER_LAUNCH_CONFIG:
			get_tree().change_scene_to_file("res://scenes/player/BattleScreen.tscn")
		_:
			get_tree().change_scene_to_file("res://scenes/sandbox/BattleSandbox.tscn")
