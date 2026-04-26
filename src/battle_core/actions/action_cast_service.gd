extends RefCounted
class_name ActionCastService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{"field": "action_cast_mp_service", "source": "action_cast_mp_service", "nested": true},
	{"field": "action_cast_target_service", "source": "action_cast_target_service", "nested": true},
	{"field": "action_cast_hit_service", "source": "action_cast_hit_service", "nested": true},
	{"field": "action_cast_segment_service", "source": "action_cast_segment_service", "nested": true},
	{"field": "action_cast_effect_dispatch_service", "source": "action_cast_effect_dispatch_service", "nested": true},
	{"field": "trigger_batch_runner", "source": "trigger_batch_runner", "nested": true},
]

const SOURCE_KIND_ORDER_ACTIVE_SKILL := 2

var action_cast_mp_service: ActionCastMpService
var action_cast_target_service: ActionCastTargetService
var action_cast_hit_service: ActionCastHitService
var action_cast_segment_service: ActionCastSegmentService
var action_cast_effect_dispatch_service: ActionCastEffectDispatchService
var trigger_batch_runner: TriggerBatchRunner

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)

func resolve_mp_cost(command: Command, skill_definition) -> int:
	return action_cast_mp_service.resolve_mp_cost(command, skill_definition)

func consume_mp(actor, consumed_mp: int) -> Array:
	return action_cast_mp_service.consume_mp(actor, consumed_mp)

func apply_action_start_resource_changes(queued_action: QueuedAction, battle_state: BattleState, actor, command: Command, cause_event_id: String) -> void:
	action_cast_mp_service.apply_action_start_resource_changes(queued_action, battle_state, actor, command, cause_event_id)

func mark_once_per_battle_usage(actor, command: Command, skill_definition) -> void:
	action_cast_mp_service.mark_once_per_battle_usage(actor, command, skill_definition)

func resolve_target(queued_action: QueuedAction, battle_state: BattleState) -> Variant:
	return action_cast_target_service.resolve_target(queued_action, battle_state)

func is_action_target_valid(command: Command, queued_action: QueuedAction, resolved_target) -> bool:
	return action_cast_target_service.is_action_target_valid(command, queued_action, resolved_target)

func resolve_target_instance_id(queued_action: QueuedAction, resolved_target) -> Variant:
	return action_cast_target_service.resolve_target_instance_id(queued_action, resolved_target)

func resolve_hit(command: Command, skill_definition, resolved_target, battle_state: BattleState, content_index: BattleContentIndex) -> Dictionary:
	return action_cast_hit_service.resolve_hit(command, skill_definition, resolved_target, battle_state, content_index)

func is_damage_action(command: Command, skill_definition) -> bool:
	return action_cast_segment_service.is_damage_action(command, skill_definition)

func apply_direct_damage(queued_action: QueuedAction, actor, target, skill_definition, battle_state: BattleState, content_index: BattleContentIndex, cause_event_id: String) -> Dictionary:
	return action_cast_segment_service.apply_direct_damage(
		queued_action,
		actor,
		target,
		skill_definition,
		battle_state,
		content_index,
		cause_event_id,
		SOURCE_KIND_ORDER_ACTIVE_SKILL
	)

func apply_default_recoil(queued_action: QueuedAction, actor, battle_state: BattleState, cause_event_id: String) -> void:
	action_cast_segment_service.apply_default_recoil(
		queued_action,
		actor,
		battle_state,
		cause_event_id,
		SOURCE_KIND_ORDER_ACTIVE_SKILL
	)

func dispatch_skill_effects(effect_ids: PackedStringArray, trigger_name: String, queued_action: QueuedAction, actor, battle_state: BattleState, content_index: BattleContentIndex, result) -> void:
	action_cast_effect_dispatch_service.dispatch_skill_effects(
		effect_ids,
		trigger_name,
		queued_action,
		actor,
		battle_state,
		content_index,
		result,
		SOURCE_KIND_ORDER_ACTIVE_SKILL
	)

func dispatch_receive_action_hit_trigger(resolved_target, battle_state: BattleState, content_index: BattleContentIndex) -> Variant:
	return action_cast_segment_service.dispatch_receive_action_hit_trigger(resolved_target, battle_state, content_index)

func trigger_batch_executor() -> Callable:
	if trigger_batch_runner == null:
		return Callable()
	return Callable(trigger_batch_runner, "execute_trigger_batch")
