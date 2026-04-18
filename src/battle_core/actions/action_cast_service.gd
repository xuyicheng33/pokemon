extends RefCounted
class_name ActionCastService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "mp_service",
		"source": "mp_service",
		"nested": true,
	},
	{
		"field": "action_hit_resolution_service",
		"source": "action_hit_resolution_service",
		"nested": true,
	},
	{
		"field": "target_resolver",
		"source": "target_resolver",
		"nested": true,
	},
	{
		"field": "trigger_batch_runner",
		"source": "trigger_batch_runner",
		"nested": true,
	},
	{
		"field": "action_log_service",
		"source": "action_log_service",
		"nested": true,
	},
	{
		"field": "action_cast_direct_damage_pipeline",
		"source": "action_cast_direct_damage_pipeline",
		"nested": true,
	},
	{
		"field": "action_cast_skill_effect_dispatch_pipeline",
		"source": "action_cast_skill_effect_dispatch_pipeline",
		"nested": true,
	},
]

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ActionCastDamageSegmentHelperScript := preload("res://src/battle_core/actions/action_cast_damage_segment_helper.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const SOURCE_KIND_ORDER_ACTIVE_SKILL := 2

var mp_service
var action_hit_resolution_service
var target_resolver
var trigger_batch_runner
var action_log_service
var action_cast_direct_damage_pipeline
var action_cast_skill_effect_dispatch_pipeline

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func resolve_mp_cost(command, skill_definition) -> int:
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

func resolve_target(queued_action, battle_state) -> Variant:
	return target_resolver.resolve_target(queued_action, battle_state)

func is_action_target_valid(command, queued_action, resolved_target) -> bool:
	if command.command_type == CommandTypesScript.SWITCH:
		return true
	if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
		return true
	if resolved_target == null:
		return false
	return resolved_target.leave_state == LeaveStatesScript.ACTIVE and resolved_target.current_hp > 0

func resolve_target_instance_id(queued_action, resolved_target) -> Variant:
	if resolved_target == null:
		return null
	if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
		return null
	return resolved_target.unit_instance_id

func resolve_hit(command, skill_definition, resolved_target, battle_state, content_index) -> Dictionary:
	return action_hit_resolution_service.resolve_hit(
		command,
		skill_definition,
		resolved_target,
		battle_state,
		content_index
	)

func is_damage_action(command, skill_definition) -> bool:
	if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT:
		return true
	return ActionCastDamageSegmentHelperScript.has_damage_truth(skill_definition)

func apply_direct_damage(queued_action, actor, target, skill_definition, battle_state, content_index, cause_event_id: String) -> Dictionary:
	return action_cast_direct_damage_pipeline.apply_direct_damage(
		queued_action,
		actor,
		target,
		skill_definition,
		battle_state,
		content_index,
		cause_event_id,
		SOURCE_KIND_ORDER_ACTIVE_SKILL
	)

func apply_default_recoil(queued_action, actor, battle_state, cause_event_id: String) -> void:
	action_cast_direct_damage_pipeline.apply_default_recoil(
		queued_action,
		actor,
		battle_state,
		cause_event_id,
		SOURCE_KIND_ORDER_ACTIVE_SKILL
	)

func dispatch_skill_effects(effect_ids: PackedStringArray, trigger_name: String, queued_action, actor, battle_state, content_index, result) -> void:
	action_cast_skill_effect_dispatch_pipeline.dispatch_skill_effects(
		effect_ids,
		trigger_name,
		queued_action,
		actor,
		battle_state,
		content_index,
		result,
		SOURCE_KIND_ORDER_ACTIVE_SKILL
	)

func execute_lifecycle_trigger_batch(trigger_name: String, battle_state, content_index, owner_unit_ids: Array) -> Variant:
	return trigger_batch_runner.execute_trigger_batch(
		trigger_name,
		battle_state,
		content_index,
		owner_unit_ids,
		battle_state.chain_context
	)

func trigger_batch_executor() -> Callable:
	if trigger_batch_runner == null:
		return Callable()
	return Callable(trigger_batch_runner, "execute_trigger_batch")
