extends RefCounted
class_name PlayerSelectionAdapter

func build_player_payload(selected_action: Dictionary) -> Dictionary:
    return {
        "command_type": selected_action.get("command_type", ""),
        "skill_id": selected_action.get("skill_id", ""),
        "target_public_id": selected_action.get("target_public_id", ""),
        "target_slot": selected_action.get("target_slot", ""),
    }
