extends RefCounted
class_name ActionDamageSegmentTriggerContextService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func execute_receive_damage_segment_trigger(
	queued_action,
	battle_state,
	content_index,
	target_unit_id: String,
	segment_index: int,
	segment_total: int,
	segment_combat_type_id: String,
	trigger_batch_runner
) -> Variant:
	if queued_action == null or battle_state == null or battle_state.chain_context == null:
		return null
	if not _should_dispatch_receive_damage_segment(queued_action, battle_state, target_unit_id):
		return null
	var previous_state := _capture_chain_context_state(battle_state.chain_context)
	_apply_segment_context(
		battle_state.chain_context,
		target_unit_id,
		segment_index,
		segment_total,
		segment_combat_type_id
	)
	var invalid_code = trigger_batch_runner.execute_trigger_batch(
		ContentSchemaScript.TRIGGER_ON_RECEIVE_ACTION_DAMAGE_SEGMENT,
		battle_state,
		content_index,
		[target_unit_id],
		battle_state.chain_context
	)
	_restore_chain_context_state(battle_state.chain_context, previous_state)
	return invalid_code

func _should_dispatch_receive_damage_segment(queued_action, battle_state, target_unit_id: String) -> bool:
	if queued_action.command == null:
		return false
	var command_type := String(queued_action.command.command_type)
	if command_type != CommandTypesScript.SKILL and command_type != CommandTypesScript.ULTIMATE:
		return false
	if queued_action.target_snapshot == null:
		return false
	if String(queued_action.target_snapshot.target_kind) != ContentSchemaScript.TARGET_ENEMY_ACTIVE:
		return false
	var actor_id := String(queued_action.command.actor_id)
	if actor_id.is_empty() or target_unit_id.is_empty():
		return false
	var actor_side = battle_state.get_side_for_unit(actor_id)
	var target_side = battle_state.get_side_for_unit(target_unit_id)
	if actor_side == null or target_side == null:
		return false
	return String(actor_side.side_id) != String(target_side.side_id)

func _apply_segment_context(chain_context, target_unit_id: String, segment_index: int, segment_total: int, segment_combat_type_id: String) -> void:
	chain_context.action_segment_index = segment_index
	chain_context.action_segment_total = segment_total
	chain_context.action_combat_type_id = segment_combat_type_id
	chain_context.target_unit_id = target_unit_id

func _capture_chain_context_state(chain_context) -> Dictionary:
	return {
		"action_segment_index": int(chain_context.action_segment_index),
		"action_segment_total": int(chain_context.action_segment_total),
		"action_combat_type_id": String(chain_context.action_combat_type_id),
		"target_unit_id": chain_context.target_unit_id,
	}

func _restore_chain_context_state(chain_context, previous_state: Dictionary) -> void:
	chain_context.action_segment_index = int(previous_state.get("action_segment_index", 0))
	chain_context.action_segment_total = int(previous_state.get("action_segment_total", 0))
	chain_context.action_combat_type_id = String(previous_state.get("action_combat_type_id", ""))
	chain_context.target_unit_id = previous_state.get("target_unit_id", null)
