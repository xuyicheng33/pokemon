extends RefCounted
class_name LogEvent

var battle_seed: int = 0
var battle_rng_profile: String = ""
var log_schema_version: int = 3
var turn_index: int = 0
var event_type: String = ""
var event_chain_id: String = ""
var event_step_id: int = 0
var chain_origin: String = ""
var trigger_name: Variant = null
var cause_event_id: Variant = null
var killer_id: Variant = null
var action_id: Variant = null
var action_queue_index: Variant = null
var actor_id: Variant = null
var source_instance_id: String = ""
var target_instance_id: Variant = null
var command_type: Variant = null
var command_source: Variant = null
var priority: int = 0
var target_slot: Variant = null
var action_window_passed: Variant = null
var has_acted: Variant = null
var leave_reason: Variant = null
var speed_tie_roll: Variant = null
var hit_roll: Variant = null
var effect_roll: Variant = null
var rng_stream_index: int = 0
var select_deadline_ms: Variant = null
var select_timeout: Variant = null
var invalid_battle_code: Variant = null
var type_effectiveness: Variant = null
var value_changes: Array = []
var field_change = null
var payload_summary: String = ""
var header_snapshot: Variant = null

func to_stable_dict() -> Dictionary:
    var value_change_dicts: Array = []
    for value_change in value_changes:
        value_change_dicts.append(value_change.to_stable_dict())
    return {
        "battle_seed": battle_seed,
        "battle_rng_profile": battle_rng_profile,
        "log_schema_version": log_schema_version,
        "turn_index": turn_index,
        "event_type": event_type,
        "event_chain_id": event_chain_id,
        "event_step_id": event_step_id,
        "chain_origin": chain_origin,
        "trigger_name": trigger_name,
        "cause_event_id": cause_event_id,
        "killer_id": killer_id,
        "action_id": action_id,
        "action_queue_index": action_queue_index,
        "actor_id": actor_id,
        "source_instance_id": source_instance_id,
        "target_instance_id": target_instance_id,
        "command_type": command_type,
        "command_source": command_source,
        "priority": priority,
        "target_slot": target_slot,
        "action_window_passed": action_window_passed,
        "has_acted": has_acted,
        "leave_reason": leave_reason,
        "speed_tie_roll": speed_tie_roll,
        "hit_roll": hit_roll,
        "effect_roll": effect_roll,
        "rng_stream_index": rng_stream_index,
        "select_deadline_ms": select_deadline_ms,
        "select_timeout": select_timeout,
        "invalid_battle_code": invalid_battle_code,
        "type_effectiveness": type_effectiveness,
        "value_changes": value_change_dicts,
        "field_change": field_change.to_stable_dict() if field_change != null else null,
        "payload_summary": payload_summary,
        "header_snapshot": header_snapshot,
    }
