extends SceneTree

const ManualBattleSceneContextSupportScript := preload("res://tests/support/manual_battle_scene_context_support.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")

var _context_support = ManualBattleSceneContextSupportScript.new()
var _launch_config_helper = BattleSandboxLaunchConfigScript.new()

func _init() -> void:
	var demo_profile_id := str(OS.get_environment("DEMO_PROFILE")).strip_edges()
	if demo_profile_id.is_empty():
		push_error("DEMO_PROFILE is required")
		quit(1)
		return
	var launch_config := _launch_config_helper.default_config()
	launch_config["mode"] = BattleSandboxLaunchConfigScript.MODE_DEMO_REPLAY
	launch_config["demo_profile_id"] = demo_profile_id
	var context_result = _context_support.build_manual_scene_context(BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED, launch_config)
	if not bool(context_result.get("ok", false)):
		push_error(str(context_result.get("error", "demo replay bootstrap failed")))
		quit(1)
		return
	var context: Dictionary = context_result
	var battle_summary: Dictionary = context.get("battle_summary", {}).duplicate(true)
	if battle_summary.is_empty():
		push_error("demo replay battle_summary is empty")
		var close_error = _context_support.close_context(context)
		if not bool(close_error.get("ok", false)):
			push_error(str(close_error.get("error", "demo replay close_context failed")))
		quit(1)
		return
	battle_summary["demo_profile_id"] = demo_profile_id
	var close_result = _context_support.close_context(context)
	if not bool(close_result.get("ok", false)):
		push_error(str(close_result.get("error", "demo replay close_context failed")))
		quit(1)
		return
	print(JSON.stringify(battle_summary))
	quit(0)
