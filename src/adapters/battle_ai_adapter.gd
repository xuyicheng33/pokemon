extends RefCounted
class_name BattleAIAdapter

const BattleAIPolicyServiceScript := preload("res://src/adapters/ai/battle_ai_policy_service.gd")

var _policy_service = BattleAIPolicyServiceScript.new()

func choose_command(legal_action_set, public_snapshot: Dictionary = {}, side_id: String = "", policy: String = "heuristic") -> Dictionary:
    return _policy_service.choose_command(legal_action_set, public_snapshot, side_id, policy)
