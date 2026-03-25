extends RefCounted
class_name CommandValidator

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func validate_command(command, battle_state, content_index) -> bool:
    if command == null:
        return false
    if battle_state.get_side(command.side_id) == null:
        return false
    _resolve_runtime_ids(command, battle_state)
    if battle_state.get_unit(command.actor_id) == null:
        return false
    if command.turn_index != battle_state.turn_index:
        return false
    var side_state = battle_state.get_side(command.side_id)
    var active_unit = side_state.get_active_unit()
    if active_unit == null or active_unit.unit_instance_id != command.actor_id:
        return false
    match command.command_type:
        CommandTypesScript.SKILL:
            return _validate_skill(command, active_unit, content_index, false)
        CommandTypesScript.ULTIMATE:
            return _validate_skill(command, active_unit, content_index, true)
        CommandTypesScript.SWITCH:
            return side_state.has_bench_unit(command.target_unit_id) and battle_state.get_unit(command.target_unit_id).current_hp > 0
        CommandTypesScript.RESOURCE_FORCED_DEFAULT:
            if command.command_source != "resource_auto":
                return false
            return true
        CommandTypesScript.TIMEOUT_DEFAULT:
            return command.command_source == "timeout_auto"
        CommandTypesScript.SURRENDER:
            return true
        _:
            return false

func _resolve_runtime_ids(command, battle_state) -> void:
    if not command.actor_public_id.is_empty():
        var actor_unit = battle_state.get_unit_by_public_id(command.actor_public_id)
        assert(actor_unit != null, "Unknown actor public id: %s" % command.actor_public_id)
        command.actor_id = actor_unit.unit_instance_id
    if not command.target_public_id.is_empty():
        var target_unit = battle_state.get_unit_by_public_id(command.target_public_id)
        assert(target_unit != null, "Unknown target public id: %s" % command.target_public_id)
        command.target_unit_id = target_unit.unit_instance_id

func _validate_skill(command, active_unit, content_index, require_ultimate: bool) -> bool:
    var unit_definition = content_index.units.get(active_unit.definition_id)
    if unit_definition == null:
        return false
    var skill_definition = content_index.skills.get(command.skill_id)
    if skill_definition == null:
        return false
    if require_ultimate:
        if unit_definition.ultimate_skill_id != command.skill_id:
            return false
    elif not unit_definition.skill_ids.has(command.skill_id):
        return false
    return active_unit.current_mp >= skill_definition.mp_cost
