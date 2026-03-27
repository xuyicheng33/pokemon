extends RefCounted
class_name BattleAIAdapter

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func choose_command(legal_action_set) -> Dictionary:
    if not legal_action_set.legal_skill_ids.is_empty():
        return {"command_type": CommandTypesScript.SKILL, "skill_id": legal_action_set.legal_skill_ids[0]}
    if not legal_action_set.legal_ultimate_ids.is_empty():
        return {"command_type": CommandTypesScript.ULTIMATE, "skill_id": legal_action_set.legal_ultimate_ids[0]}
    if not legal_action_set.legal_switch_target_ids.is_empty():
        return {"command_type": CommandTypesScript.SWITCH, "target_unit_id": legal_action_set.legal_switch_target_ids[0]}
    if legal_action_set.wait_allowed:
        return {"command_type": CommandTypesScript.WAIT}
    return {"command_type": legal_action_set.forced_command_type}
