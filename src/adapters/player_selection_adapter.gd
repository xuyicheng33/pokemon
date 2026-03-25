extends RefCounted
class_name PlayerSelectionAdapter

func build_player_payload(selected_action: Dictionary) -> Dictionary:
    return {
        "command_type": selected_action.get("command_type", ""),
        "skill_id": selected_action.get("skill_id", ""),
        "target_unit_id": selected_action.get("target_unit_id", ""),
        "target_slot": selected_action.get("target_slot", ""),
    }
