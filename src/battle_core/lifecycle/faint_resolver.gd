extends RefCounted
class_name FaintResolver

const EventTypesScript := preload("res://src/shared/event_types.gd")

var leave_service
var replacement_service
var field_service
var trigger_dispatcher
var trigger_batch_runner
var battle_logger
var log_event_builder
var faint_killer_attribution_service
var faint_leave_replacement_service

func resolve_missing_dependency() -> String:
    if leave_service == null:
        return "leave_service"
    if leave_service.has_method("resolve_missing_dependency"):
        var leave_service_missing := str(leave_service.resolve_missing_dependency())
        if not leave_service_missing.is_empty():
            return "leave_service.%s" % leave_service_missing
    if replacement_service == null:
        return "replacement_service"
    if replacement_service.has_method("resolve_missing_dependency"):
        var replacement_missing := str(replacement_service.resolve_missing_dependency())
        if not replacement_missing.is_empty():
            return "replacement_service.%s" % replacement_missing
    if field_service == null:
        return "field_service"
    if field_service.has_method("resolve_missing_dependency"):
        var field_missing := str(field_service.resolve_missing_dependency())
        if not field_missing.is_empty():
            return "field_service.%s" % field_missing
    if trigger_dispatcher == null:
        return "trigger_dispatcher"
    if trigger_batch_runner == null:
        return "trigger_batch_runner"
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if faint_killer_attribution_service == null:
        return "faint_killer_attribution_service"
    var killer_missing := str(faint_killer_attribution_service.resolve_missing_dependency())
    if not killer_missing.is_empty():
        return "faint_killer_attribution_service.%s" % killer_missing
    if faint_leave_replacement_service == null:
        return "faint_leave_replacement_service"
    var faint_leave_missing := str(faint_leave_replacement_service.resolve_missing_dependency())
    if not faint_leave_missing.is_empty():
        return "faint_leave_replacement_service.%s" % faint_leave_missing
    return ""

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
    faint_killer_attribution_service.record_fatal_damage(
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
    var fainted_units: Array = faint_leave_replacement_service.collect_pending_fainted_units(battle_state)

    if not fainted_units.is_empty():
        var faint_invalid_code = _resolve_fainted_units_and_exit(battle_state, content_index, fainted_units)
        if faint_invalid_code != null:
            return faint_invalid_code

    var replacement_resolution: Dictionary = faint_leave_replacement_service.resolve_faint_replacements(battle_state)
    var replacement_invalid_code = replacement_resolution.get("invalid_code", null)
    if replacement_invalid_code != null:
        return replacement_invalid_code
    var entered_unit_ids: Array = replacement_resolution.get("entered_unit_ids", [])
    if not entered_unit_ids.is_empty():
        var on_enter_invalid_code = _execute_unit_trigger_batch("on_enter", battle_state, content_index, entered_unit_ids)
        if on_enter_invalid_code != null:
            return on_enter_invalid_code
    if faint_leave_replacement_service.has_pending_faint_active(battle_state):
        return resolve_faint_window(battle_state, content_index)
    return null

func _resolve_fainted_units_and_exit(battle_state, content_index, fainted_units: Array) -> Variant:
    var fainted_unit_ids: Array = faint_leave_replacement_service.collect_unit_ids(fainted_units)
    var killer_by_target: Dictionary = {}
    for fainted_unit_id in fainted_unit_ids:
        killer_by_target[fainted_unit_id] = faint_killer_attribution_service.resolve_killer_for_target(battle_state, fainted_unit_id)
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
    var killer_resolution: Dictionary = faint_killer_attribution_service.resolve_killer_units(battle_state, fainted_unit_ids)
    var killer_unit_ids: Array = killer_resolution["killer_unit_ids"]
    if not killer_unit_ids.is_empty():
        var action_on_kill_events_result: Dictionary = faint_killer_attribution_service.collect_action_on_kill_events(
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
    var exit_invalid_code = faint_leave_replacement_service.resolve_fainted_units_leave(
        battle_state,
        content_index,
        fainted_units,
        Callable(self, "_execute_unit_trigger_batch")
    )
    if exit_invalid_code != null:
        return exit_invalid_code
    faint_killer_attribution_service.clear_fatal_damage_records(battle_state, fainted_unit_ids)
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
