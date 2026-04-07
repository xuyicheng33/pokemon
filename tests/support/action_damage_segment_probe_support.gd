extends RefCounted
class_name ActionDamageSegmentProbeSupport

const ActionDamageSegmentTriggerContextServiceScript := preload("res://src/battle_core/actions/action_damage_segment_trigger_context_service.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const QueuedActionScript := preload("res://src/battle_core/contracts/queued_action.gd")
const TargetSnapshotScript := preload("res://src/battle_core/contracts/target_snapshot.gd")

var _segment_trigger_context_service = ActionDamageSegmentTriggerContextServiceScript.new()

func run_enemy_segment_trigger(
	core,
	battle_state,
	content_index,
	command,
	actor_id: String,
	target_unit_id: String,
	segment_index: int,
	segment_total: int,
	segment_combat_type_id: String
) -> Variant:
	var queued_action = QueuedActionScript.new()
	queued_action.command = command
	queued_action.target_snapshot = TargetSnapshotScript.new()
	queued_action.target_snapshot.target_kind = "enemy_active_slot"
	queued_action.target_snapshot.target_unit_id = target_unit_id
	battle_state.chain_context = build_chain_context(
		actor_id,
		target_unit_id,
		String(command.command_type),
		String(command.command_source),
		segment_combat_type_id,
		segment_index,
		segment_total
	)
	return _segment_trigger_context_service.execute_receive_damage_segment_trigger(
		queued_action,
		battle_state,
		content_index,
		target_unit_id,
		segment_index,
		segment_total,
		segment_combat_type_id,
		core.service("trigger_batch_runner")
	)

func build_chain_context(
	actor_id: String,
	target_unit_id: String,
	command_type: String,
	command_source: String,
	segment_combat_type_id: String,
	segment_index: int,
	segment_total: int
):
	var chain_context = ChainContextScript.new()
	chain_context.event_chain_id = "test_action_damage_segment_probe"
	chain_context.chain_origin = "action"
	chain_context.command_type = command_type
	chain_context.command_source = command_source
	chain_context.actor_id = actor_id
	chain_context.action_actor_id = actor_id
	chain_context.target_unit_id = target_unit_id
	chain_context.action_combat_type_id = segment_combat_type_id
	chain_context.action_segment_index = segment_index
	chain_context.action_segment_total = segment_total
	return chain_context
