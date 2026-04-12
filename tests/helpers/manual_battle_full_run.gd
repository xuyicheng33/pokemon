extends SceneTree

const ManualBattleSceneSupportScript := preload("res://tests/support/manual_battle_scene_support.gd")

var _support = ManualBattleSceneSupportScript.new()

func _init() -> void:
	var battle_seed = int(str(OS.get_environment("BATTLE_SEED")).to_int())
	if battle_seed <= 0:
		battle_seed = 9111
	var context_result = _support.build_manual_scene_context(null, battle_seed)
	if not bool(context_result.get("ok", false)):
		push_error(str(context_result.get("error", "manual battle bootstrap failed")))
		quit(1)
		return
	var context: Dictionary = context_result
	var run_result = _support.run_to_battle_end(context, 64)
	var close_result = _support.close_context(context)
	if not bool(run_result.get("ok", false)):
		push_error(str(run_result.get("error", "manual battle full run failed")))
		quit(1)
		return
	if not bool(close_result.get("ok", false)):
		push_error(str(close_result.get("error", "manual battle close_context failed")))
		quit(1)
		return
	print(JSON.stringify({
		"battle_seed": battle_seed,
		"battle_result": run_result.get("battle_result", null),
		"turn_index": int(run_result.get("turn_index", 0)),
		"event_log_cursor": int(run_result.get("event_log_cursor", 0)),
		"command_steps": int(run_result.get("command_steps", 0)),
	}))
	quit(0)
