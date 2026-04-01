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
        var dependency = controller_deps.get(dependency_name, null)
        if dependency == null:
            return dependency_name
        var nested_missing := _resolve_object_missing_dependency(dependency)
        if not nested_missing.is_empty():
            return "%s.%s" % [dependency_name, nested_missing]
    return ""

func _resolve_object_missing_dependency(dependency) -> String:
    if dependency == null:
        return "missing"
    if dependency.has_method("resolve_missing_dependency"):
        return str(dependency.resolve_missing_dependency())
    return ""

func validate_runtime_state(battle_state, content_index = null):
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
        if side_state.get_active_unit() == null and _side_has_available_unit(side_state):
            return ErrorCodesScript.INVALID_STATE_CORRUPTION
    if battle_state.field_state != null:
        if battle_state.field_state.remaining_turns < 0:
            return ErrorCodesScript.INVALID_STATE_CORRUPTION
        if String(battle_state.field_state.field_def_id).strip_edges().is_empty():
            return ErrorCodesScript.INVALID_STATE_CORRUPTION
        if String(battle_state.field_state.creator).is_empty():
            return ErrorCodesScript.INVALID_STATE_CORRUPTION
        if battle_state.get_unit(String(battle_state.field_state.creator)) == null:
            return ErrorCodesScript.INVALID_STATE_CORRUPTION
        if content_index != null and content_index.fields.get(String(battle_state.field_state.field_def_id), null) == null:
            return ErrorCodesScript.INVALID_STATE_CORRUPTION
    return null

func _side_has_available_unit(side_state) -> bool:
    if side_state == null:
        return false
    for unit_state in side_state.team_units:
        if unit_state.current_hp > 0:
            return true
    return false
