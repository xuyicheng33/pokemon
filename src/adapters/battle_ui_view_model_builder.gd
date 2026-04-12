extends RefCounted
class_name BattleUIViewModelBuilder

func build_view_model(public_snapshot: Dictionary, context: Dictionary = {}) -> Dictionary:
    if public_snapshot == null:
        return {}
    var side_models: Array = []
    for raw_side_snapshot in public_snapshot.get("sides", []):
        if not (raw_side_snapshot is Dictionary):
            continue
        var side_snapshot: Dictionary = raw_side_snapshot
        var unit_lookup := _build_unit_lookup(side_snapshot.get("team_units", []))
        var active_public_id := str(side_snapshot.get("active_public_id", "")).strip_edges()
        var bench_public_ids := _to_string_array(side_snapshot.get("bench_public_ids", []))
        var bench_units: Array = []
        for public_id in bench_public_ids:
            bench_units.append(_build_unit_model(unit_lookup.get(public_id, {})))
        var team_units: Array = []
        for unit_snapshot in side_snapshot.get("team_units", []):
            if unit_snapshot is Dictionary:
                team_units.append(_build_unit_model(unit_snapshot))
        side_models.append({
            "side_id": str(side_snapshot.get("side_id", "")).strip_edges(),
            "active_public_id": active_public_id,
            "active": _build_unit_model(unit_lookup.get(active_public_id, {})),
            "bench_public_ids": bench_public_ids,
            "bench": bench_units,
            "team_units": team_units,
        })
    side_models.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return str(left.get("side_id", "")) < str(right.get("side_id", ""))
    )
    var pending_commands := _build_pending_commands_summary(context.get("pending_commands", {}))
    var legal_actions_by_side := _build_legal_actions_summary_by_side(context.get("legal_actions_by_side", {}))
    return {
        "battle_id": str(public_snapshot.get("battle_id", "")).strip_edges(),
        "turn_index": int(public_snapshot.get("turn_index", 0)),
        "phase": str(public_snapshot.get("phase", "")).strip_edges(),
        "visibility_mode": str(public_snapshot.get("visibility_mode", "")).strip_edges(),
        "field_id": str(public_snapshot.get("field_id", "")).strip_edges(),
        "field": public_snapshot.get("field", {}).duplicate(true) if public_snapshot.get("field", null) is Dictionary else {},
        "sides": side_models,
        "prebattle_public_teams": public_snapshot.get("prebattle_public_teams", []).duplicate(true),
        "battle_result": public_snapshot.get("battle_result", null),
        "current_side_to_select": str(context.get("current_side_to_select", "")).strip_edges(),
        "pending_commands": pending_commands,
        "legal_actions_by_side": legal_actions_by_side,
        "recent_event_lines": _to_string_array(context.get("recent_event_lines", [])),
        "error_message": str(context.get("error_message", "")).strip_edges(),
    }

func _build_pending_commands_summary(raw_pending_commands: Dictionary) -> Array:
    var summaries: Array = []
    for raw_side_id in raw_pending_commands.keys():
        var side_id := str(raw_side_id).strip_edges()
        var command = raw_pending_commands.get(raw_side_id, null)
        summaries.append({
            "side_id": side_id,
            "command_type": str(_read_property(command, "command_type", "")).strip_edges(),
            "actor_public_id": str(_read_property(command, "actor_public_id", "")).strip_edges(),
            "skill_id": str(_read_property(command, "skill_id", "")).strip_edges(),
            "target_public_id": str(_read_property(command, "target_public_id", "")).strip_edges(),
        })
    summaries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return str(left.get("side_id", "")) < str(right.get("side_id", ""))
    )
    return summaries

func _build_legal_actions_summary_by_side(raw_legal_actions_by_side: Dictionary) -> Dictionary:
    var summaries: Dictionary = {}
    for raw_side_id in raw_legal_actions_by_side.keys():
        var side_id := str(raw_side_id).strip_edges()
        var legal_actions = raw_legal_actions_by_side.get(raw_side_id, null)
        summaries[side_id] = {
            "actor_public_id": str(_read_property(legal_actions, "actor_public_id", "")).strip_edges(),
            "legal_skill_ids": _to_string_array(_read_property(legal_actions, "legal_skill_ids", [])),
            "legal_switch_target_public_ids": _to_string_array(_read_property(legal_actions, "legal_switch_target_public_ids", [])),
            "legal_ultimate_ids": _to_string_array(_read_property(legal_actions, "legal_ultimate_ids", [])),
            "wait_allowed": bool(_read_property(legal_actions, "wait_allowed", false)),
            "forced_command_type": str(_read_property(legal_actions, "forced_command_type", "")).strip_edges(),
        }
    return summaries

func _build_unit_lookup(raw_team_units: Array) -> Dictionary:
    var lookup: Dictionary = {}
    for raw_unit in raw_team_units:
        if not (raw_unit is Dictionary):
            continue
        var unit_snapshot: Dictionary = raw_unit
        var public_id := str(unit_snapshot.get("public_id", "")).strip_edges()
        if public_id.is_empty():
            continue
        lookup[public_id] = unit_snapshot
    return lookup

func _build_unit_model(unit_snapshot: Dictionary) -> Dictionary:
    if unit_snapshot == null or unit_snapshot.is_empty():
        return {}
    var effects: Array = []
    for raw_effect in unit_snapshot.get("effect_instances", []):
        if not (raw_effect is Dictionary):
            continue
        var effect_snapshot: Dictionary = raw_effect
        effects.append({
            "effect_definition_id": str(effect_snapshot.get("effect_definition_id", "")).strip_edges(),
            "remaining": int(effect_snapshot.get("remaining", 0)),
            "persists_on_switch": bool(effect_snapshot.get("persists_on_switch", false)),
        })
    return {
        "public_id": str(unit_snapshot.get("public_id", "")).strip_edges(),
        "definition_id": str(unit_snapshot.get("definition_id", "")).strip_edges(),
        "display_name": str(unit_snapshot.get("display_name", "")).strip_edges(),
        "current_hp": int(unit_snapshot.get("current_hp", 0)),
        "max_hp": int(unit_snapshot.get("max_hp", 0)),
        "current_mp": int(unit_snapshot.get("current_mp", 0)),
        "max_mp": int(unit_snapshot.get("max_mp", 0)),
        "ultimate_points": int(unit_snapshot.get("ultimate_points", 0)),
        "ultimate_points_cap": int(unit_snapshot.get("ultimate_points_cap", 0)),
        "ultimate_points_required": int(unit_snapshot.get("ultimate_points_required", 0)),
        "is_active": bool(unit_snapshot.get("is_active", false)),
        "active_slot": str(unit_snapshot.get("active_slot", "")).strip_edges(),
        "combat_type_ids": _to_string_array(unit_snapshot.get("combat_type_ids", [])),
        "stat_stages": unit_snapshot.get("stat_stages", {}).duplicate(true) if unit_snapshot.get("stat_stages", null) is Dictionary else {},
        "leave_state": str(unit_snapshot.get("leave_state", "")).strip_edges(),
        "leave_reason": str(unit_snapshot.get("leave_reason", "")).strip_edges(),
        "effects": effects,
    }

func _read_property(value, property_name: String, default_value = null):
    if value == null or property_name.is_empty():
        return default_value
    if value is Dictionary:
        return value.get(property_name, default_value)
    if typeof(value) != TYPE_OBJECT:
        return default_value
    for property_info in value.get_property_list():
        if str(property_info.get("name", "")) == property_name:
            return value.get(property_name)
    return default_value

func _to_string_array(raw_value) -> Array:
    var result: Array = []
    if raw_value == null:
        return result
    if raw_value is PackedStringArray:
        for raw_item in raw_value:
            result.append(str(raw_item).strip_edges())
        return result
    if raw_value is Array:
        for raw_item in raw_value:
            result.append(str(raw_item).strip_edges())
    return result
