extends RefCounted
class_name ActionCastSkillEffectDispatchPipeline

var trigger_dispatcher: TriggerDispatcher
var effect_queue_service: EffectQueueService
var payload_executor: PayloadExecutor
var rng_service: RngService
var trigger_batch_runner: TriggerBatchRunner


func dispatch_skill_effects(effect_ids: PackedStringArray, trigger_name: String, queued_action, actor, battle_state, content_index, result, source_kind_order_active_skill: int) -> void:
	if effect_ids.is_empty():
		return
	var effect_events = trigger_dispatcher.collect_events(
		trigger_name,
		battle_state,
		content_index,
		effect_ids,
		actor.unit_instance_id,
		queued_action.action_id,
		source_kind_order_active_skill,
		queued_action.speed_snapshot,
		battle_state.chain_context
	)
	if trigger_dispatcher.invalid_battle_code() != null:
		result.invalid_battle_code = trigger_dispatcher.invalid_battle_code()
		return
	if effect_events.is_empty():
		return
	battle_state.pending_effect_queue = effect_events
	var sorted_events = effect_queue_service.sort_events(effect_events, rng_service)
	battle_state.rng_stream_index = rng_service.get_stream_index()
	for effect_event in sorted_events:
		payload_executor.execute_effect_event(
			effect_event,
			battle_state,
			content_index,
			Callable(trigger_batch_runner, "execute_trigger_batch")
		)
		if payload_executor.invalid_battle_code() != null:
			result.invalid_battle_code = payload_executor.invalid_battle_code()
			break
		result.generated_effects.append(effect_event)
	battle_state.pending_effect_queue.clear()
