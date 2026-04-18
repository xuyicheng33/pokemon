extends RefCounted
class_name ReplayRunnerOutputHelper

const ReplayOutputScript := preload("res://src/battle_core/contracts/replay_output.gd")
const DeepCopyHelperScript := preload("res://src/shared/deep_copy_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ReplayRunnerOutputValidatorScript := preload("res://src/battle_core/logging/replay_runner_output_validator.gd")

var _validator = ReplayRunnerOutputValidatorScript.new()

func build_replay_output(event_log: Array, battle_state, logger_error_state: Dictionary = {}, turn_timeline: Array = []):
	return build_replay_output_result(event_log, battle_state, logger_error_state, turn_timeline).get("replay_output", null)

func compute_state_hash(battle_state) -> String:
	return _compute_state_hash(battle_state)

func build_replay_output_result(
	event_log: Array,
	battle_state,
	logger_error_state: Dictionary = {},
	turn_timeline: Array = []
) -> Dictionary:
	var replay_output = ReplayOutputScript.new()
	replay_output.event_log = event_log
	replay_output.turn_timeline = turn_timeline.duplicate(true) if turn_timeline is Array else []
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
	if not _validator.validate_log_schema_v3(replay_output.event_log):
		replay_output.succeeded = false
		return _error_result(
			replay_output,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"ReplayRunner replay log schema validation failed"
		)
	if not _validator.validate_battle_result(battle_state.battle_result):
		replay_output.succeeded = false
		return _error_result(
			replay_output,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"ReplayRunner replay returned invalid battle_result"
		)
	if not _validator.validate_turn_timeline(replay_output.turn_timeline, replay_output.event_log):
		replay_output.succeeded = false
		return _error_result(
			replay_output,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"ReplayRunner replay turn_timeline validation failed"
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

func build_turn_frame(
	turn_index: int,
	public_snapshot: Dictionary,
	event_from: int,
	event_to: int,
	battle_finished: bool
) -> Dictionary:
	return DeepCopyHelperScript.copy_value({
		"turn_index": turn_index,
		"public_snapshot": public_snapshot if public_snapshot is Dictionary else {},
		"event_from": event_from,
		"event_to": event_to,
		"battle_finished": battle_finished,
	})

func _compute_state_hash(battle_state) -> String:
	var json_text := JSON.stringify(battle_state.to_stable_dict())
	var hashing_context = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(json_text.to_utf8_buffer())
	return hashing_context.finish().hex_encode()

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
