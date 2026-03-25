extends RefCounted
class_name FaintResolver

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var leave_service
var replacement_service
var passive_skill_service
var passive_item_service
var field_service
var effect_queue_service
var payload_executor
var rng_service
var battle_logger
var log_event_builder

func resolve_faint_window(battle_state, content_index):
    var fainted_units: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null:
            continue
        if active_unit.current_hp <= 0 and active_unit.leave_state == LeaveStatesScript.ACTIVE:
            active_unit.leave_state = LeaveStatesScript.FAINTED_PENDING_LEAVE
            active_unit.leave_reason = "faint"
            fainted_units.append(active_unit)

    if not fainted_units.is_empty():
        for fainted_unit in fainted_units:
            battle_logger.append_event(log_event_builder.build_event(
                EventTypesScript.STATE_FAINT,
                battle_state,
                {
                    "source_instance_id": fainted_unit.unit_instance_id,
                    "target_instance_id": fainted_unit.unit_instance_id,
                    "leave_reason": "faint",
                    "payload_summary": "%s fainted" % fainted_unit.public_id,
                }
            ))
        var fainted_unit_ids: Array = []
        for fainted_unit in fainted_units:
            fainted_unit_ids.append(fainted_unit.unit_instance_id)
        var on_faint_invalid_code = _execute_unit_trigger_batch("on_faint", battle_state, content_index, fainted_unit_ids)
        if on_faint_invalid_code != null:
            return on_faint_invalid_code
        var killer_unit_ids: Array = _collect_killer_unit_ids(battle_state, fainted_unit_ids)
        if not killer_unit_ids.is_empty():
            var on_kill_invalid_code = _execute_unit_trigger_batch("on_kill", battle_state, content_index, killer_unit_ids)
            if on_kill_invalid_code != null:
                return on_kill_invalid_code
        for fainted_unit in fainted_units:
            leave_service.leave_unit(battle_state, fainted_unit, "faint")
        var on_exit_invalid_code = _execute_unit_trigger_batch("on_exit", battle_state, content_index, fainted_unit_ids)
        if on_exit_invalid_code != null:
            return on_exit_invalid_code

    var entered_unit_ids: Array = []
    for side_state in battle_state.sides:
        if side_state.get_active_unit() == null:
            var entered_unit = replacement_service.resolve_replacement(battle_state, side_state)
            if entered_unit != null:
                entered_unit_ids.append(entered_unit.unit_instance_id)
    if not entered_unit_ids.is_empty():
        var on_enter_invalid_code = _execute_unit_trigger_batch("on_enter", battle_state, content_index, entered_unit_ids)
        if on_enter_invalid_code != null:
            return on_enter_invalid_code
    if _has_pending_faint_active(battle_state):
        return resolve_faint_window(battle_state, content_index)
    return null

func _execute_unit_trigger_batch(trigger_name: String, battle_state, content_index, owner_unit_ids: Array):
    var effect_events: Array = []
    effect_events.append_array(passive_skill_service.collect_trigger_events(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context))
    effect_events.append_array(passive_item_service.collect_trigger_events(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context))
    effect_events.append_array(field_service.collect_trigger_events(trigger_name, battle_state, content_index, battle_state.chain_context))
    if effect_events.is_empty():
        return null
    battle_state.pending_effect_queue = effect_events
    var sorted_events = effect_queue_service.sort_events(effect_events, rng_service)
    battle_state.rng_stream_index = rng_service.get_stream_index()
    for effect_event in sorted_events:
        payload_executor.execute_effect_event(effect_event, battle_state, content_index)
        if payload_executor.last_invalid_battle_code != null:
            battle_state.pending_effect_queue.clear()
            return payload_executor.last_invalid_battle_code
    battle_state.pending_effect_queue.clear()
    return null

func _collect_killer_unit_ids(battle_state, fainted_unit_ids: Array) -> Array:
    if battle_state.chain_context == null:
        return []
    var actor_id = battle_state.chain_context.actor_id
    if actor_id == null:
        return []
    if fainted_unit_ids.has(actor_id):
        return []
    var actor_unit = battle_state.get_unit(str(actor_id))
    if actor_unit == null or actor_unit.current_hp <= 0:
        return []
    return [actor_unit.unit_instance_id]

func _has_pending_faint_active(battle_state) -> bool:
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null:
            continue
        if active_unit.current_hp <= 0 and active_unit.leave_state == LeaveStatesScript.ACTIVE:
            return true
    return false
