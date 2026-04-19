extends RefCounted
class_name ReplacementEntryHelper

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func enter_replacement(battle_state: BattleState, side_state, slot_id: String, selected_unit_id: String, battle_logger, log_event_builder) -> Variant:
	var bench_unit = battle_state.get_unit(selected_unit_id)
	if bench_unit == null or bench_unit.current_hp <= 0 or not side_state.has_bench_unit(selected_unit_id):
		return null
	side_state.set_active_unit(slot_id, selected_unit_id)
	var bench_index: int = side_state.bench_order.find(selected_unit_id)
	if bench_index >= 0:
		side_state.bench_order.remove_at(bench_index)
	bench_unit.leave_state = LeaveStatesScript.ACTIVE
	bench_unit.leave_reason = null
	bench_unit.reentered_turn_index = battle_state.turn_index
	bench_unit.has_acted = false
	bench_unit.action_window_passed = false
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.STATE_REPLACE,
		battle_state,
		{
			"source_instance_id": bench_unit.unit_instance_id,
			"target_instance_id": bench_unit.unit_instance_id,
			"target_slot": slot_id,
			"trigger_name": "replace",
			"payload_summary": "%s replaced into battle" % bench_unit.public_id,
		}
	))
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.STATE_ENTER,
		battle_state,
		{
			"source_instance_id": bench_unit.unit_instance_id,
			"target_instance_id": bench_unit.unit_instance_id,
			"target_slot": slot_id,
			"trigger_name": "on_enter",
			"payload_summary": "%s entered battle" % bench_unit.public_id,
		}
	))
	return bench_unit
