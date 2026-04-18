extends RefCounted
class_name ActionStartPhaseService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "action_cast_service",
		"source": "action_cast_service",
		"nested": true,
	},
	{
		"field": "action_log_service",
		"source": "action_log_service",
		"nested": true,
	},
]

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

var action_cast_service
var action_log_service

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func apply_action_start_phase(queued_action, battle_state, actor, command, skill_definition) -> Dictionary:
    actor.action_window_passed = true
    actor.has_acted = true
    var consumed_mp: int = action_cast_service.resolve_mp_cost(command, skill_definition)
    var mp_changes: Array = action_cast_service.consume_mp(actor, consumed_mp)
    _mark_once_per_battle_usage(actor, command, skill_definition)
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

func _mark_once_per_battle_usage(actor, command, skill_definition) -> void:
    if actor == null or command == null or skill_definition == null:
        return
    if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
        return
    if not bool(skill_definition.once_per_battle):
        return
    actor.mark_once_per_battle_skill_used(String(skill_definition.id))
