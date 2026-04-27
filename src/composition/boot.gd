extends Node
class_name Boot

const PLAYER_LAUNCH_CONFIG := "player_mvp"
const SANDBOX_LAUNCH_CONFIG := "sandbox"

const CLI_PLAYER_FLAG := "--player_mvp"
const CLI_SANDBOX_FLAG := "--sandbox"

@export var launch_config: String = SANDBOX_LAUNCH_CONFIG  # 默认走 sandbox 不影响测试基线

func _ready() -> void:
	call_deferred("_open")

func _open() -> void:
	var resolved_config := _resolve_launch_config_from_cli(launch_config)
	match resolved_config:
		PLAYER_LAUNCH_CONFIG:
			get_tree().change_scene_to_file("res://scenes/player/BattleScreen.tscn")
		_:
			get_tree().change_scene_to_file("res://scenes/sandbox/BattleSandbox.tscn")

func _resolve_launch_config_from_cli(default_config: String) -> String:
	# 命令行用户参数（双破折号后传给 godot --path . -- <user_args>）覆盖 export 默认值。
	var user_args := OS.get_cmdline_user_args()
	for raw_arg in user_args:
		var arg := str(raw_arg).strip_edges()
		if arg == CLI_PLAYER_FLAG:
			return PLAYER_LAUNCH_CONFIG
		if arg == CLI_SANDBOX_FLAG:
			return SANDBOX_LAUNCH_CONFIG
	return default_config
