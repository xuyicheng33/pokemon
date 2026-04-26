extends RefCounted
class_name LogEventBuilder

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const LogEventScript := preload("res://src/battle_core/contracts/log_event.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")

var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func build_event(event_type: String, battle_state: BattleState, payload: Dictionary = {}) -> Variant:
	_clear_error()
	if event_type.begins_with("effect:"):
		var raw_cause_event_id = payload.get("cause_event_id", null)
		if raw_cause_event_id == null or String(raw_cause_event_id).strip_edges().is_empty():
			var contract_message := "LogEventBuilder.build_event refuses effect:* without cause_event_id; use build_effect_event for %s" % event_type
			push_error(contract_message)
			assert(false, contract_message)
			return _fail(contract_message, battle_state)
	if battle_state == null:
		return _fail("LogEventBuilder.build_event requires battle_state")
	var chain_context = battle_state.chain_context
	if chain_context == null:
		return _fail("LogEventBuilder.build_event missing chain_context", battle_state)
	if String(chain_context.event_chain_id).is_empty():
		return _fail("LogEventBuilder.build_event missing event_chain_id", battle_state)
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

func build_effect_event(event_type: String, battle_state: BattleState, cause_event_id: String, payload: Dictionary = {}) -> Variant:
	_clear_error()
	if not event_type.begins_with("effect:"):
		return _fail("LogEventBuilder.build_effect_event only accepts effect:* events", battle_state)
	if cause_event_id.strip_edges().is_empty():
		return _fail("LogEventBuilder.build_effect_event requires real cause_event_id", battle_state)
	var effect_payload := payload.duplicate()
	effect_payload["cause_event_id"] = cause_event_id
	return build_event(event_type, battle_state, effect_payload)

func resolve_event_id(log_event) -> String:
	if log_event == null:
		_fail("LogEventBuilder.resolve_event_id requires log_event")
		return ""
	return "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]

func _clear_error() -> void:
	ErrorStateHelperScript.clear(self)

func _fail(message: String, battle_state: BattleState = null) -> Variant:
	ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_STATE_CORRUPTION, message)
	if battle_state != null:
		battle_state.runtime_fault_code = String(last_error_code)
		battle_state.runtime_fault_message = message
		if battle_state.battle_result != null and not bool(battle_state.battle_result.finished):
			battle_state.battle_result.finished = true
			battle_state.battle_result.winner_side_id = null
			battle_state.battle_result.result_type = "no_winner"
			battle_state.battle_result.reason = String(last_error_code)
			battle_state.phase = BattlePhasesScript.FINISHED
			battle_state.chain_context = null
	return null
