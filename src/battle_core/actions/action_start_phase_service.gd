extends RefCounted
class_name ActionStartPhaseService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

var action_cast_service
var action_log_service

func resolve_missing_dependency() -> String:
    if action_cast_service == null:
        return "action_cast_service"
    var cast_missing := str(action_cast_service.resolve_missing_dependency())
    if not cast_missing.is_empty():
        return "action_cast_service.%s" % cast_missing
    if action_log_service == null:
        return "action_log_service"
    var log_missing := str(action_log_service.resolve_missing_dependency())
    if not log_missing.is_empty():
        return "action_log_service.%s" % log_missing
    return ""

func apply_action_start_phase(queued_action, battle_state, actor, command, skill_definition) -> Dictionary:
    actor.action_window_passed = true
    actor.has_acted = true
    var consumed_mp: int = action_cast_service.resolve_mp_cost(command, skill_definition)
    var mp_changes: Array = action_cast_service.consume_mp(actor, consumed_mp)
    var action_cast_event_id: String = action_log_service.log_action_cast(queued_action, battle_state, command, mp_changes)
    _apply_action_start_resource_changes(queued_action, battle_state, actor, command, action_cast_event_id)
    var result_type: Variant = null
    if command.command_type == CommandTypesScript.WAIT:
        result_type = "resolved"
    return {
        "action_cast_event_id": action_cast_event_id,
        "consumed_mp": consumed_mp,
        "result_type": result_type,
    }

func _apply_action_start_resource_changes(queued_action, battle_state, actor, command, cause_event_id: String) -> void:
    if actor == null:
        return
    match command.command_type:
        CommandTypesScript.SKILL:
            _gain_ultimate_points(queued_action, battle_state, actor, cause_event_id)
        CommandTypesScript.ULTIMATE:
            _clear_ultimate_points(queued_action, battle_state, actor, cause_event_id)

func _gain_ultimate_points(queued_action, battle_state, actor, cause_event_id: String) -> void:
    if actor.ultimate_points_cap <= 0 or actor.ultimate_point_gain_on_regular_skill_cast <= 0:
        return
    var before_points: int = actor.ultimate_points
    actor.ultimate_points = min(actor.ultimate_points_cap, actor.ultimate_points + actor.ultimate_point_gain_on_regular_skill_cast)
    action_log_service.log_action_resource_change(
        queued_action,
        battle_state,
        actor,
        "ultimate_points",
        before_points,
        actor.ultimate_points,
        cause_event_id,
        "%s ultimate_points %+d (%d/%d)" % [actor.public_id, actor.ultimate_points - before_points, actor.ultimate_points, actor.ultimate_points_cap]
    )

func _clear_ultimate_points(queued_action, battle_state, actor, cause_event_id: String) -> void:
    var before_points: int = actor.ultimate_points
    actor.ultimate_points = 0
    action_log_service.log_action_resource_change(
        queued_action,
        battle_state,
        actor,
        "ultimate_points",
        before_points,
        actor.ultimate_points,
        cause_event_id,
        "%s ultimate_points reset (%d/%d)" % [actor.public_id, actor.ultimate_points, actor.ultimate_points_cap]
    )
