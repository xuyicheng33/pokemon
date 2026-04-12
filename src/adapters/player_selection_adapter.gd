extends RefCounted
class_name PlayerSelectionAdapter

func build_player_payload(selected_action: Dictionary) -> Dictionary:
    var payload := {
        "command_type": str(selected_action.get("command_type", "")).strip_edges(),
        "side_id": str(selected_action.get("side_id", "")).strip_edges(),
        "actor_public_id": str(selected_action.get("actor_public_id", "")).strip_edges(),
        "command_source": _resolve_command_source(selected_action),
    }
    if selected_action.has("turn_index"):
        payload["turn_index"] = int(selected_action.get("turn_index", 1))
    var skill_id := str(selected_action.get("skill_id", "")).strip_edges()
    if not skill_id.is_empty():
        payload["skill_id"] = skill_id
    var target_public_id := str(selected_action.get("target_public_id", "")).strip_edges()
    if not target_public_id.is_empty():
        payload["target_public_id"] = target_public_id
    var target_slot := str(selected_action.get("target_slot", "")).strip_edges()
    if not target_slot.is_empty():
        payload["target_slot"] = target_slot
    return payload

func _resolve_command_source(selected_action: Dictionary) -> String:
    var command_source := str(selected_action.get("command_source", "manual")).strip_edges()
    if command_source.is_empty():
        return "manual"
    return command_source
