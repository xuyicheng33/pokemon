extends RefCounted
class_name LogEventBuilder

const LogEventScript := preload("res://src/battle_core/contracts/log_event.gd")

func build_event(event_type: String, battle_state, payload: Dictionary = {}):
    var chain_context = battle_state.chain_context
    assert(chain_context != null, "LogEventBuilder.build_event missing chain_context")
    assert(not String(chain_context.event_chain_id).is_empty(), "LogEventBuilder.build_event missing event_chain_id")
    chain_context.step_counter += 1
    var log_event = LogEventScript.new()
    log_event.battle_seed = battle_state.seed
    log_event.battle_rng_profile = battle_state.rng_profile
    log_event.log_schema_version = 3
    log_event.turn_index = battle_state.turn_index
    log_event.event_type = event_type
    log_event.event_chain_id = chain_context.event_chain_id
    log_event.event_step_id = chain_context.step_counter
    log_event.chain_origin = chain_context.chain_origin
    log_event.action_id = chain_context.root_action_id
    log_event.action_queue_index = chain_context.action_queue_index
    log_event.actor_id = chain_context.actor_id
    log_event.command_type = chain_context.command_type
    log_event.command_source = chain_context.command_source
    log_event.target_slot = chain_context.target_slot
    log_event.select_timeout = chain_context.select_timeout
    log_event.select_deadline_ms = chain_context.select_deadline_ms
    log_event.rng_stream_index = battle_state.rng_stream_index
    for key in payload.keys():
        log_event.set(key, payload[key])
    return log_event

func build_effect_event(event_type: String, battle_state, cause_event_id: String, payload: Dictionary = {}):
    assert(event_type.begins_with("effect:"), "LogEventBuilder.build_effect_event only accepts effect:* events")
    assert(not cause_event_id.strip_edges().is_empty(), "LogEventBuilder.build_effect_event requires real cause_event_id")
    var effect_payload := payload.duplicate()
    effect_payload["cause_event_id"] = cause_event_id
    return build_event(event_type, battle_state, effect_payload)

func resolve_event_id(log_event) -> String:
    assert(log_event != null, "LogEventBuilder.resolve_event_id requires log_event")
    return "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]
