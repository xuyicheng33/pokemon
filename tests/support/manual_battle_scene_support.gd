extends RefCounted
class_name ManualBattleSceneSupport

const ManualBattleSceneContextSupportScript := preload("res://tests/support/manual_battle_scene_context_support.gd")
const ManualBattleSceneDriveSupportScript := preload("res://tests/support/manual_battle_scene_drive_support.gd")

var _context_support = ManualBattleSceneContextSupportScript.new()
var _drive_support = ManualBattleSceneDriveSupportScript.new()

func build_manual_scene_context(_harness, battle_seed: int, launch_config: Dictionary = {}) -> Dictionary:
	return _context_support.build_manual_scene_context(battle_seed, launch_config)

func close_context(context: Dictionary) -> Dictionary:
	return _context_support.close_context(context)

func get_legal_actions(context: Dictionary, side_id: String) -> Dictionary:
	return _context_support.get_legal_actions(context, side_id)

func run_hotseat_turn(context: Dictionary, p1_selected_action: Dictionary, p2_selected_action: Dictionary) -> Dictionary:
	return _drive_support.run_hotseat_turn(_context_support, context, p1_selected_action, p2_selected_action)

func run_to_battle_end(context: Dictionary, max_turns: int = 64) -> Dictionary:
	return _drive_support.run_to_battle_end(_context_support, context, max_turns)

func build_view_model(context: Dictionary) -> Dictionary:
	return _drive_support.build_view_model(context)

func validate_view_model_renderable(view_model: Dictionary) -> String:
	return _drive_support.validate_view_model_renderable(view_model)

func current_turn_index(context: Dictionary) -> int:
	return _drive_support.current_turn_index(context)
