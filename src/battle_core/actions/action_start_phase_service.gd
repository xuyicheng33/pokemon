extends RefCounted
class_name ActionStartPhaseService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

var action_cast_service: ActionCastService
var action_log_service: ActionLogService


func apply_action_start_phase(queued_action: QueuedAction, battle_state: BattleState, actor, command: Command, skill_definition) -> Dictionary:
	actor.action_window_passed = true
	actor.has_acted = true
	var consumed_mp: int = action_cast_service.resolve_mp_cost(command, skill_definition)
	var mp_changes: Array = action_cast_service.consume_mp(actor, consumed_mp)
	action_cast_service.mark_once_per_battle_usage(actor, command, skill_definition)
	var action_cast_event_id: String = action_log_service.log_action_cast(queued_action, battle_state, command, mp_changes)
	action_cast_service.apply_action_start_resource_changes(queued_action, battle_state, actor, command, action_cast_event_id)
	var result_type: Variant = null
	if command.command_type == CommandTypesScript.WAIT:
		result_type = "resolved"
	return {
		"action_cast_event_id": action_cast_event_id,
		"consumed_mp": consumed_mp,
		"result_type": result_type,
	}
