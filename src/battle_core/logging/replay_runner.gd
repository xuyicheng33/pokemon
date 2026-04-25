extends RefCounted
class_name ReplayRunner

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "battle_initializer",
		"source": "battle_initializer",
		"nested": true,
	},
	{
		"field": "turn_loop_controller",
		"source": "turn_loop_controller",
		"nested": true,
	},
	{
		"field": "battle_logger",
		"source": "battle_logger",
		"nested": true,
	},
	{
		"field": "id_factory",
		"source": "id_factory",
		"nested": true,
	},
	{
		"field": "rng_service",
		"source": "rng_service",
		"nested": true,
	},
	{
		"field": "content_snapshot_cache",
		"source": "content_snapshot_cache",
		"nested": true,
	},
	{
		"field": "public_snapshot_builder",
		"source": "public_snapshot_builder",
		"nested": true,
	},
]

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")
const ReplayRunnerInputHelperScript := preload("res://src/battle_core/logging/replay_runner_input_helper.gd")
const ReplayRunnerExecutionContextBuilderScript := preload("res://src/battle_core/logging/replay_runner_execution_context_builder.gd")
const ReplayRunnerOutputHelperScript := preload("res://src/battle_core/logging/replay_runner_output_helper.gd")

var battle_initializer: BattleInitializer
var turn_loop_controller: TurnLoopController
var battle_logger: BattleLogger
var id_factory: IdFactory
var rng_service: RngService
var content_snapshot_cache: ContentSnapshotCache
var public_snapshot_builder: BattleCorePublicSnapshotBuilder
var last_error_code: Variant = null
var last_error_message: String = ""
var _input_helper = ReplayRunnerInputHelperScript.new()
var _context_builder = ReplayRunnerExecutionContextBuilderScript.new()
var _output_helper = ReplayRunnerOutputHelperScript.new()

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func run_replay(replay_input) -> Variant:
	return run_replay_with_context(replay_input).get("replay_output", null)

func run_replay_with_context(replay_input) -> Dictionary:
	ErrorStateHelperScript.clear(self)
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
		ErrorStateHelperScript.capture_envelope(
			self,
			context_result,
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			"ReplayRunner failed to build replay context"
		)
		return {
			"replay_output": null,
			"content_index": context_result.get("content_index", null),
		}
	var content_index = context_result.get("content_index", null)
	var battle_state = context_result.get("battle_state", null)
	var max_turn_index: int = int(context_result.get("max_turn_index", 0))
	var commands_by_turn: Dictionary = _input_helper.group_commands_by_turn(replay_input.command_stream)
	var turn_timeline: Array = [
		_output_helper.build_turn_frame(
			0,
			public_snapshot_builder.build_public_snapshot(battle_state, content_index),
			0,
			0,
			false
		)
	]
	var event_from: int = 0
	var consumed_turn_indices: Dictionary = {}
	while not battle_state.battle_result.finished and battle_state.turn_index <= max_turn_index:
		var completed_turn_index: int = battle_state.turn_index
		consumed_turn_indices[completed_turn_index] = true
		var turn_commands: Array = commands_by_turn.get(battle_state.turn_index, [])
		turn_loop_controller.run_turn(battle_state, content_index, turn_commands)
		var event_to: int = battle_logger.snapshot().size()
		turn_timeline.append(
			_output_helper.build_turn_frame(
				completed_turn_index,
				public_snapshot_builder.build_public_snapshot(battle_state, content_index),
				event_from,
				event_to,
				bool(battle_state.battle_result.finished)
			)
		)
		event_from = event_to
	var unconsumed_turn_indices: Array = _input_helper.unconsumed_command_turn_indices(commands_by_turn, consumed_turn_indices)
	if not unconsumed_turn_indices.is_empty():
		return _fail(
			"ReplayRunner command_stream has unconsumed command turn_index values: %s" % JSON.stringify(unconsumed_turn_indices),
			ErrorCodesScript.INVALID_REPLAY_INPUT
		)
	var logger_error_state: Dictionary = battle_logger.error_state()
	var output_result := _output_helper.build_replay_output_result(
		battle_logger.snapshot(),
		battle_state,
		logger_error_state,
		turn_timeline
	)
	var replay_output = output_result.get("replay_output", null)
	if not bool(output_result.get("ok", false)):
		ErrorStateHelperScript.capture_envelope(
			self,
			output_result,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"ReplayRunner failed to build replay output"
		)
	return {
		"replay_output": replay_output,
		"content_index": content_index,
	}

func _fail(message: String, error_code: String = ErrorCodesScript.INVALID_REPLAY_INPUT) -> Dictionary:
	ErrorStateHelperScript.fail(self, error_code, message)
	return {"replay_output": null, "content_index": null}
