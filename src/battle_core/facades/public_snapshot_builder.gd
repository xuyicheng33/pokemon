extends RefCounted
class_name BattleCorePublicSnapshotBuilder

func build_public_snapshot(battle_state, content_index = null) -> Dictionary:
    if battle_state == null:
        return {}
    var field_snapshot = _build_public_field_snapshot(battle_state, content_index)
    var side_models: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        var bench_public_ids: Array[String] = []
        var team_units: Array = []
        for bench_unit_id in side_state.bench_order:
            var bench_unit = side_state.find_unit(str(bench_unit_id))
            if bench_unit != null:
                bench_public_ids.append(bench_unit.public_id)
        for unit_state in side_state.team_units:
            team_units.append(_build_public_unit_snapshot(side_state, unit_state))
        team_units.sort_custom(func(left, right): return String(left.get("public_id", "")) < String(right.get("public_id", "")))
        side_models.append({
            "side_id": side_state.side_id,
            "active_public_id": active_unit.public_id if active_unit != null else null,
            "active_hp": active_unit.current_hp if active_unit != null else null,
            "active_mp": active_unit.current_mp if active_unit != null else null,
            "active_ultimate_points": active_unit.ultimate_points if active_unit != null else null,
            "active_ultimate_points_cap": active_unit.ultimate_points_cap if active_unit != null else null,
            "active_ultimate_points_required": active_unit.ultimate_points_required if active_unit != null else null,
            "bench_public_ids": bench_public_ids,
            "team_units": team_units,
        })
    side_models.sort_custom(func(left, right): return String(left.get("side_id", "")) < String(right.get("side_id", "")))
    return {
        "battle_id": battle_state.battle_id,
        "turn_index": battle_state.turn_index,
        "phase": battle_state.phase,
        "visibility_mode": battle_state.visibility_mode,
        "field_id": field_snapshot["field_id"],
        "field": field_snapshot,
        "sides": side_models,
        "prebattle_public_teams": _build_prebattle_public_teams(battle_state, content_index),
        "battle_result": battle_state.battle_result.to_stable_dict() if battle_state.battle_result != null else null,
    }

func build_header_snapshot(battle_state, content_index = null) -> Dictionary:
    if battle_state == null:
        return {}
    var initial_field_snapshot: Variant = null
    if battle_state.field_state != null:
        initial_field_snapshot = _build_public_field_snapshot(battle_state, content_index)
    return {
        "visibility_mode": battle_state.visibility_mode,
        "prebattle_public_teams": _build_prebattle_public_teams(battle_state, content_index),
        "initial_active_public_ids_by_side": _build_initial_active_public_ids_by_side(battle_state),
        "initial_field": initial_field_snapshot,
    }

func _build_public_unit_snapshot(side_state, unit_state) -> Dictionary:
    var is_active: bool = false
    var active_slot: Variant = null
    for slot_id in side_state.active_slots.keys():
        if str(side_state.active_slots[slot_id]) == unit_state.unit_instance_id:
            is_active = true
            active_slot = String(slot_id)
            break
    var effect_summaries: Array = []
    for effect_instance in unit_state.effect_instances:
        effect_summaries.append({
            "effect_definition_id": effect_instance.def_id,
            "remaining": effect_instance.remaining,
            "persists_on_switch": effect_instance.persists_on_switch,
            "__sort_instance_id": effect_instance.instance_id,
        })
    effect_summaries.sort_custom(func(left, right):
        var left_def := String(left.get("effect_definition_id", ""))
        var right_def := String(right.get("effect_definition_id", ""))
        if left_def != right_def:
            return left_def < right_def
        var left_remaining := int(left.get("remaining", 0))
        var right_remaining := int(right.get("remaining", 0))
        if left_remaining != right_remaining:
            return left_remaining < right_remaining
        var left_persist := int(bool(left.get("persists_on_switch", false)))
        var right_persist := int(bool(right.get("persists_on_switch", false)))
        if left_persist != right_persist:
            return left_persist < right_persist
        return String(left.get("__sort_instance_id", "")) < String(right.get("__sort_instance_id", ""))
    )
    for effect_summary in effect_summaries:
        effect_summary.erase("__sort_instance_id")
    return {
        "public_id": unit_state.public_id,
        "definition_id": unit_state.definition_id,
        "display_name": unit_state.display_name,
        "current_hp": unit_state.current_hp,
        "current_mp": unit_state.current_mp,
        "max_hp": unit_state.max_hp,
        "max_mp": unit_state.max_mp,
        "ultimate_points": unit_state.ultimate_points,
        "ultimate_points_cap": unit_state.ultimate_points_cap,
        "ultimate_points_required": unit_state.ultimate_points_required,
        "combat_type_ids": unit_state.combat_type_ids,
        "stat_stages": unit_state.get_effective_stat_stage_map(),
        "leave_state": unit_state.leave_state,
        "leave_reason": unit_state.leave_reason,
        "is_active": is_active,
        "active_slot": active_slot,
        "effect_instances": effect_summaries,
    }

func _build_public_field_snapshot(battle_state, content_index = null) -> Dictionary:
    if battle_state.field_state == null:
        return {
            "field_id": null,
            "field_kind": null,
            "remaining_turns": null,
            "creator_public_id": null,
            "creator_side_id": null,
        }
    var creator_id := String(battle_state.field_state.creator)
    if creator_id.is_empty():
        return {
            "field_id": battle_state.field_state.field_def_id,
            "field_kind": null,
            "remaining_turns": battle_state.field_state.remaining_turns,
            "creator_public_id": null,
            "creator_side_id": null,
        }
    var field_kind: Variant = null
    if content_index != null:
        var field_definition = content_index.fields.get(String(battle_state.field_state.field_def_id), null)
        if field_definition != null:
            field_kind = String(field_definition.field_kind)
    var creator_side_id: Variant = null
    var creator_side = battle_state.get_side_for_unit(creator_id)
    if creator_side != null:
        creator_side_id = String(creator_side.side_id)
    return {
        "field_id": battle_state.field_state.field_def_id,
        "field_kind": field_kind,
        "remaining_turns": battle_state.field_state.remaining_turns,
        "creator_public_id": _resolve_public_id_or_system(battle_state, creator_id),
        "creator_side_id": creator_side_id,
    }

func _build_prebattle_public_teams(battle_state, content_index) -> Array:
    if content_index == null:
        return []
    var side_models: Array = []
    for side_state in battle_state.sides:
        var unit_models: Array = []
        for unit_state in side_state.team_units:
            var unit_definition = content_index.units.get(unit_state.definition_id, null)
            if unit_definition == null:
                continue
            unit_models.append({
                "public_id": unit_state.public_id,
                "definition_id": unit_definition.id,
                "display_name": unit_definition.display_name,
                "level": battle_state.battle_level,
                "combat_type_ids": unit_definition.combat_type_ids,
                "skill_ids": unit_state.regular_skill_ids,
                "ultimate_skill_id": unit_definition.ultimate_skill_id,
                "ultimate_points_required": unit_definition.ultimate_points_required,
                "ultimate_points_cap": unit_definition.ultimate_points_cap,
                "ultimate_point_gain_on_regular_skill_cast": unit_definition.ultimate_point_gain_on_regular_skill_cast,
                "passive_skill_id": unit_definition.passive_skill_id,
                "passive_item_id": unit_definition.passive_item_id,
                "base_stats": {
                    "hp": unit_definition.base_hp,
                    "attack": unit_definition.base_attack,
                    "defense": unit_definition.base_defense,
                    "sp_attack": unit_definition.base_sp_attack,
                    "sp_defense": unit_definition.base_sp_defense,
                    "speed": unit_definition.base_speed,
                    "max_mp": unit_definition.max_mp,
                    "init_mp": unit_definition.init_mp,
                    "regen_per_turn": unit_definition.regen_per_turn,
                },
            })
        unit_models.sort_custom(func(left, right): return String(left.get("public_id", "")) < String(right.get("public_id", "")))
        side_models.append({
            "side_id": side_state.side_id,
            "units": unit_models,
        })
    side_models.sort_custom(func(left, right): return String(left.get("side_id", "")) < String(right.get("side_id", "")))
    return side_models

func _build_initial_active_public_ids_by_side(battle_state) -> Dictionary:
    var active_ids_by_side: Dictionary = {}
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        active_ids_by_side[side_state.side_id] = active_unit.public_id if active_unit != null else null
    return active_ids_by_side

func _resolve_public_id_or_system(battle_state, source_id: String) -> Variant:
    if source_id.is_empty():
        return null
    var source_unit = battle_state.get_unit(source_id)
    if source_unit != null:
        return source_unit.public_id
    return source_id
