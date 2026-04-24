extends SceneTree

const ManualBattleSceneSupportScript := preload("res://tests/support/manual_battle_scene_support.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")

var _support = ManualBattleSceneSupportScript.new()
var _launch_config_helper = BattleSandboxLaunchConfigScript.new()

func _init() -> void:
	var battle_seed = int(str(OS.get_environment("BATTLE_SEED")).to_int())
	if battle_seed <= 0:
		battle_seed = BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED
	var launch_config := _launch_config_helper.default_config()
	launch_config[BattleSandboxLaunchConfigScript.STRICT_CONFIG_KEY] = true
	var matchup_id := str(OS.get_environment("MATCHUP_ID")).strip_edges()
	if not matchup_id.is_empty():
		launch_config["matchup_id"] = matchup_id
	var p1_mode := str(OS.get_environment("P1_MODE")).strip_edges()
	if not p1_mode.is_empty():
		launch_config["p1_control_mode"] = p1_mode
	var p2_mode := str(OS.get_environment("P2_MODE")).strip_edges()
	if not p2_mode.is_empty():
		launch_config["p2_control_mode"] = p2_mode
	var context_result = _support.build_manual_scene_context(null, battle_seed, launch_config)
	if not bool(context_result.get("ok", false)):
		push_error(str(context_result.get("error_message", "manual submit battle bootstrap failed")))
		quit(1)
		return
	var context: Dictionary = context_result
	var run_result = _support.run_to_battle_end_via_submit(context, 64)
	var close_result = _support.close_context(context)
	if not bool(run_result.get("ok", false)):
		push_error(str(run_result.get("error_message", "manual submit battle full run failed")))
		quit(1)
		return
	if not bool(close_result.get("ok", false)):
		push_error(str(close_result.get("error_message", "manual submit battle close_context failed")))
		quit(1)
		return
	var battle_summary: Dictionary = run_result.get("battle_summary", {}).duplicate(true)
	if battle_summary.is_empty():
		battle_summary = {
			"matchup_id": str(context.get("launch_config", {}).get("matchup_id", "")),
			"battle_seed": battle_seed,
			"p1_control_mode": str(context.get("side_control_modes", {}).get("P1", "")),
			"p2_control_mode": str(context.get("side_control_modes", {}).get("P2", "")),
			"winner_side_id": "",
			"reason": "",
			"result_type": "",
			"turn_index": int(run_result.get("turn_index", 0)),
			"event_log_cursor": int(run_result.get("event_log_cursor", 0)),
			"command_steps": int(run_result.get("command_steps", 0)),
		}
	print(JSON.stringify(battle_summary))
	quit(0)
