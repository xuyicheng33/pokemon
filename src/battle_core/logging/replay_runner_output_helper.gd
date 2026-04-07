extends RefCounted
class_name ReplayRunnerOutputHelper

const ReplayOutputScript := preload("res://src/battle_core/contracts/replay_output.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func build_replay_output(event_log: Array, battle_state, logger_error_state: Dictionary = {}):
	return build_replay_output_result(event_log, battle_state, logger_error_state).get("replay_output", null)

func compute_state_hash(battle_state) -> String:
	return _compute_state_hash(battle_state)

func build_replay_output_result(event_log: Array, battle_state, logger_error_state: Dictionary = {}) -> Dictionary:
	var replay_output = ReplayOutputScript.new()
	replay_output.event_log = event_log
	replay_output.final_state_hash = ""
	replay_output.battle_result = battle_state.battle_result if battle_state != null else null
	replay_output.final_battle_state = battle_state
	if battle_state == null:
		replay_output.succeeded = false
		return _error_result(
			replay_output,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"ReplayRunner replay returned null battle_state"
		)
	var runtime_fault_code = battle_state.runtime_fault_code
	if runtime_fault_code != null and not String(runtime_fault_code).is_empty():
		replay_output.succeeded = false
		return _error_result(
			replay_output,
			String(runtime_fault_code),
			String(battle_state.runtime_fault_message) if not String(battle_state.runtime_fault_message).is_empty() else "ReplayRunner replay entered invalid runtime state"
		)
	var logger_error_code = logger_error_state.get("code", null)
	if logger_error_code != null:
		var logger_error_message := String(logger_error_state.get("message", ""))
		replay_output.succeeded = false
		return _error_result(
			replay_output,
			String(logger_error_code),
			logger_error_message if not logger_error_message.is_empty() else "ReplayRunner replay log state invalid"
		)
	var run_completed: bool = battle_state != null and battle_state.battle_result != null and battle_state.battle_result.finished
	if not run_completed:
		replay_output.succeeded = false
		return _error_result(
			replay_output,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"ReplayRunner replay did not complete"
		)
	if not _validate_log_schema_v3(replay_output.event_log):
		replay_output.succeeded = false
		return _error_result(
			replay_output,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"ReplayRunner replay log schema validation failed"
		)
	if not _validate_battle_result(battle_state.battle_result):
		replay_output.succeeded = false
		return _error_result(
			replay_output,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"ReplayRunner replay returned invalid battle_result"
		)
	replay_output.final_state_hash = compute_state_hash(battle_state)
	replay_output.succeeded = true
	replay_output.failure_code = ""
	replay_output.failure_message = ""
	return {
		"ok": true,
		"replay_output": replay_output,
		"error_code": null,
		"error_message": "",
	}

func _compute_state_hash(battle_state) -> String:
	var json_text := JSON.stringify(battle_state.to_stable_dict())
	var hashing_context = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(json_text.to_utf8_buffer())
	return hashing_context.finish().hex_encode()

func _validate_log_schema_v3(event_log: Array) -> bool:
	var battle_header_count: int = 0
	for log_event in event_log:
		if log_event == null:
			return false
		if int(log_event.log_schema_version) != 3:
			return false
		if String(log_event.chain_origin).is_empty():
			return false
		if String(log_event.chain_origin) != "action":
			if String(log_event.command_type).is_empty():
				return false
			if not String(log_event.command_type).begins_with("system:"):
				return false
			if String(log_event.command_source) != "system":
				return false
		if String(log_event.event_type).is_empty():
			return false
		if String(log_event.event_chain_id).is_empty():
			return false
		if int(log_event.event_step_id) <= 0:
			return false
		if String(log_event.event_type) == EventTypesScript.SYSTEM_BATTLE_HEADER:
			battle_header_count += 1
			if String(log_event.command_type) != EventTypesScript.SYSTEM_BATTLE_HEADER:
				return false
			if not _validate_header_snapshot(log_event.header_snapshot):
				return false
		if String(log_event.event_type).begins_with("effect:"):
			if log_event.trigger_name == null:
				return false
			if log_event.cause_event_id == null or String(log_event.cause_event_id).is_empty():
				return false
			if String(log_event.cause_event_id) == "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]:
				return false
	return battle_header_count == 1

func _validate_header_snapshot(header_snapshot) -> bool:
	if typeof(header_snapshot) != TYPE_DICTIONARY:
		return false
	var required_fields: Array[String] = [
		"visibility_mode",
		"prebattle_public_teams",
		"initial_active_public_ids_by_side",
		"initial_field",
	]
	for field_name in required_fields:
		if not header_snapshot.has(field_name):
			return false
	return not _contains_private_instance_id_key(header_snapshot)

func _contains_private_instance_id_key(value) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value.keys():
			var key_text := String(key)
			if key_text == "unit_instance_id" or key_text.ends_with("_instance_id"):
				return true
			if _contains_private_instance_id_key(value[key]):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for element in value:
			if _contains_private_instance_id_key(element):
				return true
	return false

func _validate_battle_result(battle_result) -> bool:
	if battle_result == null:
		return false
	if not battle_result.finished:
		return false
	if String(battle_result.result_type).is_empty():
		return false
	if String(battle_result.reason).is_empty():
		return false
	if battle_result.result_type == "win":
		return battle_result.winner_side_id != null
	if battle_result.result_type == "draw" or battle_result.result_type == "no_winner":
		return battle_result.winner_side_id == null
	return false

func _error_result(replay_output, error_code: String, error_message: String) -> Dictionary:
	if replay_output != null:
		replay_output.failure_code = error_code
		replay_output.failure_message = error_message
	return {
		"ok": false,
		"replay_output": replay_output,
		"error_code": error_code,
		"error_message": error_message,
	}
