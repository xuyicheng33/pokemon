extends RefCounted
class_name ActionCastMpService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

const COMPOSE_DEPS := [
	{"field": "mp_service", "source": "mp_service", "nested": true},
	{"field": "action_log_service", "source": "action_log_service", "nested": true},
]

var mp_service: MpService
var action_log_service: ActionLogService

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)

func resolve_mp_cost(command: Command, skill_definition) -> int:
	if command.command_type == CommandTypesScript.SKILL or command.command_type == CommandTypesScript.ULTIMATE:
		return skill_definition.mp_cost
	return 0

func consume_mp(actor, consumed_mp: int) -> Array:
	var mp_changes: Array = []
	if consumed_mp > 0:
		var before_mp: int = actor.current_mp
		actor.current_mp = mp_service.consume_mp(actor.current_mp, consumed_mp)
		mp_changes.append(action_log_service.build_value_change(actor.unit_instance_id, "mp", before_mp, actor.current_mp))
	return mp_changes

func apply_action_start_resource_changes(queued_action: QueuedAction, battle_state: BattleState, actor, command: Command, cause_event_id: String) -> void:
	if actor == null:
		return
	match command.command_type:
		CommandTypesScript.SKILL:
			_gain_ultimate_points(queued_action, battle_state, actor, cause_event_id)
		CommandTypesScript.ULTIMATE:
			_clear_ultimate_points(queued_action, battle_state, actor, cause_event_id)

func mark_once_per_battle_usage(actor, command: Command, skill_definition) -> void:
	if actor == null or command == null or skill_definition == null:
		return
	if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
		return
	if not bool(skill_definition.once_per_battle):
		return
	actor.mark_once_per_battle_skill_used(String(skill_definition.id))

func _gain_ultimate_points(queued_action: QueuedAction, battle_state: BattleState, actor, cause_event_id: String) -> void:
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

func _clear_ultimate_points(queued_action: QueuedAction, battle_state: BattleState, actor, cause_event_id: String) -> void:
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
