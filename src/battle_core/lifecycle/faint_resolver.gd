extends RefCounted
class_name FaintResolver

const FaintKillerAttributionServiceScript := preload("res://src/battle_core/lifecycle/faint_killer_attribution_service.gd")
const FaintLeaveReplacementServiceScript := preload("res://src/battle_core/lifecycle/faint_leave_replacement_service.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var leave_service
var replacement_service
var field_service
var trigger_dispatcher
var trigger_batch_runner
var battle_logger
var log_event_builder

var _killer_attribution_service := FaintKillerAttributionServiceScript.new()
var _leave_replacement_service := FaintLeaveReplacementServiceScript.new()

func record_fatal_damage(
    battle_state,
    target_unit_id: String,
    before_hp: int,
    after_hp: int,
    killer_unit_id: Variant,
    source_instance_id: String,
    source_kind_order: int,
    source_order_speed_snapshot: int,
    priority: int,
    cause_event_step_id: int
) -> void:
    _sync_subservices()
    _killer_attribution_service.record_fatal_damage(
        battle_state,
        target_unit_id,
        before_hp,
        after_hp,
        killer_unit_id,
        source_instance_id,
        source_kind_order,
        source_order_speed_snapshot,
        priority,
        cause_event_step_id
    )

func resolve_faint_window(battle_state, content_index):
    _sync_subservices()
    var fainted_units: Array = _leave_replacement_service.collect_pending_fainted_units(battle_state)

    if not fainted_units.is_empty():
        var faint_invalid_code = _resolve_fainted_units_and_exit(battle_state, content_index, fainted_units)
        if faint_invalid_code != null:
            return faint_invalid_code

    var replacement_resolution: Dictionary = _leave_replacement_service.resolve_faint_replacements(battle_state)
    var replacement_invalid_code = replacement_resolution.get("invalid_code", null)
    if replacement_invalid_code != null:
        return replacement_invalid_code
    var entered_unit_ids: Array = replacement_resolution.get("entered_unit_ids", [])
    if not entered_unit_ids.is_empty():
        var on_enter_invalid_code = _execute_unit_trigger_batch("on_enter", battle_state, content_index, entered_unit_ids)
        if on_enter_invalid_code != null:
            return on_enter_invalid_code
    if _leave_replacement_service.has_pending_faint_active(battle_state):
        return resolve_faint_window(battle_state, content_index)
    return null

func _resolve_fainted_units_and_exit(battle_state, content_index, fainted_units: Array) -> Variant:
    var fainted_unit_ids: Array = _leave_replacement_service.collect_unit_ids(fainted_units)
    var killer_by_target: Dictionary = {}
    for fainted_unit_id in fainted_unit_ids:
        killer_by_target[fainted_unit_id] = _killer_attribution_service.resolve_killer_for_target(battle_state, fainted_unit_id)
    for fainted_unit in fainted_units:
        battle_logger.append_event(log_event_builder.build_event(
            EventTypesScript.STATE_FAINT,
            battle_state,
            {
                "source_instance_id": fainted_unit.unit_instance_id,
                "target_instance_id": fainted_unit.unit_instance_id,
                "leave_reason": "faint",
                "killer_id": killer_by_target.get(fainted_unit.unit_instance_id, null),
                "trigger_name": "on_faint",
                "payload_summary": "%s fainted" % fainted_unit.public_id,
            }
        ))
    var on_faint_invalid_code = _execute_unit_trigger_batch("on_faint", battle_state, content_index, fainted_unit_ids)
    if on_faint_invalid_code != null:
        return on_faint_invalid_code
    var killer_resolution: Dictionary = _killer_attribution_service.resolve_killer_units(battle_state, fainted_unit_ids)
    var killer_unit_ids: Array = killer_resolution["killer_unit_ids"]
    if not killer_unit_ids.is_empty():
        var action_on_kill_events_result: Dictionary = _killer_attribution_service.collect_action_on_kill_events(
            battle_state,
            content_index,
            killer_unit_ids
        )
        if action_on_kill_events_result["invalid_code"] != null:
            return action_on_kill_events_result["invalid_code"]
        var on_kill_invalid_code = _execute_unit_trigger_batch(
            "on_kill",
            battle_state,
            content_index,
            killer_unit_ids,
            action_on_kill_events_result["events"]
        )
        if on_kill_invalid_code != null:
            return on_kill_invalid_code
    var exit_invalid_code = _leave_replacement_service.resolve_fainted_units_leave(
        battle_state,
        content_index,
        fainted_units,
        Callable(self, "_execute_unit_trigger_batch")
    )
    if exit_invalid_code != null:
        return exit_invalid_code
    _killer_attribution_service.clear_fatal_damage_records(battle_state, fainted_unit_ids)
    return null

func _execute_unit_trigger_batch(trigger_name: String, battle_state, content_index, owner_unit_ids: Array, extra_effect_events: Array = []):
    return trigger_batch_runner.execute_trigger_batch(
        trigger_name,
        battle_state,
        content_index,
        owner_unit_ids,
        battle_state.chain_context,
        extra_effect_events
    )

func _sync_subservices() -> void:
    _killer_attribution_service.trigger_dispatcher = trigger_dispatcher
    _leave_replacement_service.leave_service = leave_service
    _leave_replacement_service.replacement_service = replacement_service
    _leave_replacement_service.field_service = field_service
