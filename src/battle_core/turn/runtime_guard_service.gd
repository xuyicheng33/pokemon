extends RefCounted
class_name RuntimeGuardService

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func resolve_missing_dependency(controller_deps: Dictionary) -> String:
    var required: PackedStringArray = PackedStringArray([
        "action_queue_builder",
        "action_executor",
        "faint_resolver",
        "turn_resolution_service",
        "battle_result_service",
    ])
    for dependency_name in required:
        if controller_deps.get(dependency_name, null) == null:
            return dependency_name
    var turn_resolution_service = controller_deps.get("turn_resolution_service")
    var turn_resolution_missing := str(turn_resolution_service.resolve_missing_dependency())
    if not turn_resolution_missing.is_empty():
        return "turn_resolution_service.%s" % turn_resolution_missing
    var battle_result_service = controller_deps.get("battle_result_service")
    var battle_result_missing := str(battle_result_service.resolve_missing_dependency())
    if not battle_result_missing.is_empty():
        return "battle_result_service.%s" % battle_result_missing
    return ""

func validate_runtime_state(battle_state):
    if battle_state.chain_context == null:
        return ErrorCodesScript.INVALID_STATE_CORRUPTION
    if battle_state.max_chain_depth <= 0:
        return ErrorCodesScript.INVALID_STATE_CORRUPTION
    for side_state in battle_state.sides:
        for unit_state in side_state.team_units:
            if unit_state.max_hp <= 0 or unit_state.max_mp < 0:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
            if unit_state.current_hp < 0 or unit_state.current_hp > unit_state.max_hp:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
            if unit_state.current_mp < 0 or unit_state.current_mp > unit_state.max_mp:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
            if unit_state.ultimate_points_cap < 0 or unit_state.ultimate_points_required < 0:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
            if unit_state.ultimate_points < 0 or unit_state.ultimate_points > unit_state.ultimate_points_cap:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
        for slot_id in side_state.active_slots.keys():
            var active_unit_id: String = str(side_state.active_slots[slot_id])
            if active_unit_id.is_empty() or side_state.find_unit(active_unit_id) == null:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
    if battle_state.field_state != null and battle_state.field_state.remaining_turns < 0:
        return ErrorCodesScript.INVALID_STATE_CORRUPTION
    return null
