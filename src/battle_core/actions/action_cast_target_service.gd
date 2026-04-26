extends RefCounted
class_name ActionCastTargetService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

const COMPOSE_DEPS := [
	{"field": "target_resolver", "source": "target_resolver", "nested": true},
]

var target_resolver: TargetResolver

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)

func resolve_target(queued_action: QueuedAction, battle_state: BattleState) -> Variant:
	return target_resolver.resolve_target(queued_action, battle_state)

func is_action_target_valid(command: Command, queued_action: QueuedAction, resolved_target) -> bool:
	if command.command_type == CommandTypesScript.SWITCH:
		return true
	if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
		return true
	if resolved_target == null:
		return false
	return resolved_target.leave_state == LeaveStatesScript.ACTIVE and resolved_target.current_hp > 0

func resolve_target_instance_id(queued_action: QueuedAction, resolved_target) -> Variant:
	if resolved_target == null:
		return null
	if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
		return null
	return resolved_target.unit_instance_id
