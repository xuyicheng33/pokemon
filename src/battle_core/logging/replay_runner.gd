extends RefCounted
class_name ReplayRunner

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ReplayRunnerInputHelperScript := preload("res://src/battle_core/logging/replay_runner_input_helper.gd")
const ReplayRunnerExecutionContextBuilderScript := preload("res://src/battle_core/logging/replay_runner_execution_context_builder.gd")
const ReplayRunnerOutputHelperScript := preload("res://src/battle_core/logging/replay_runner_output_helper.gd")

var battle_initializer
var turn_loop_controller
var battle_logger
var id_factory
var rng_service
var content_snapshot_cache
var last_error_code: Variant = null
var last_error_message: String = ""
var _input_helper = ReplayRunnerInputHelperScript.new()
var _context_builder = ReplayRunnerExecutionContextBuilderScript.new()
var _output_helper = ReplayRunnerOutputHelperScript.new()

func resolve_missing_dependency() -> String:
	if battle_initializer == null:
		return "battle_initializer"
	if turn_loop_controller == null:
		return "turn_loop_controller"
	if battle_logger == null:
		return "battle_logger"
	if id_factory == null:
		return "id_factory"
	if rng_service == null:
		return "rng_service"
	if content_snapshot_cache == null:
		return "content_snapshot_cache"
	return ""

func error_state() -> Dictionary:
	return {
		"code": last_error_code,
		"message": last_error_message,
	}

func run_replay(replay_input) -> Variant:
	return run_replay_with_context(replay_input).get("replay_output", null)

func run_replay_with_context(replay_input) -> Dictionary:
	last_error_code = null
	last_error_message = ""
	var missing_dependency := resolve_missing_dependency()
	if not missing_dependency.is_empty():
		return _fail("ReplayRunner missing dependency: %s" % missing_dependency, ErrorCodesScript.INVALID_COMPOSITION)
	var replay_input_error := _input_helper.validate_replay_input(replay_input)
	if not replay_input_error.is_empty():
		return _fail(replay_input_error, ErrorCodesScript.INVALID_REPLAY_INPUT)
	var context_result := _context_builder.build_context(
		replay_input,
		content_snapshot_cache,
		id_factory,
		rng_service,
		battle_initializer
	)
	if not bool(context_result.get("ok", false)):
		last_error_code = context_result.get("error_code", ErrorCodesScript.INVALID_REPLAY_INPUT)
		last_error_message = String(context_result.get("error_message", "ReplayRunner failed to build replay context"))
		return {
			"replay_output": null,
			"content_index": context_result.get("content_index", null),
		}
	var content_index = context_result.get("content_index", null)
	var battle_state = context_result.get("battle_state", null)
	var max_turn_index: int = int(context_result.get("max_turn_index", 0))
	var commands_by_turn: Dictionary = _input_helper.group_commands_by_turn(replay_input.command_stream)
	while not battle_state.battle_result.finished and battle_state.turn_index <= max_turn_index:
		var turn_commands: Array = commands_by_turn.get(battle_state.turn_index, [])
		turn_loop_controller.run_turn(battle_state, content_index, turn_commands)
	var replay_output = _output_helper.build_replay_output(battle_logger.snapshot(), battle_state)
	return {
		"replay_output": replay_output,
		"content_index": content_index,
	}

func _fail(message: String, error_code: String = ErrorCodesScript.INVALID_REPLAY_INPUT) -> Dictionary:
	last_error_code = error_code
	last_error_message = message
	return {"replay_output": null, "content_index": null}
