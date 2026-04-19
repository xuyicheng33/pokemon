extends RefCounted
class_name TurnLoopValidationHelper

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_result_service: BattleResultService
var runtime_guard_service: RuntimeGuardService
var battle_logger: BattleLogger

func validate_runtime_or_terminate(battle_state, content_index = null) -> bool:
	var invalid_code = runtime_guard_service.validate_runtime_state(battle_state, content_index)
	if invalid_code == null and battle_logger != null and battle_logger.has_method("error_state"):
		var logger_error_state: Dictionary = battle_logger.error_state()
		invalid_code = logger_error_state.get("code", null)
	if invalid_code == null:
		return false
	battle_result_service.terminate_invalid_battle(battle_state, str(invalid_code))
	return true

func validate_dependencies_or_terminate(battle_state, owner) -> bool:
	var missing_dependency: String = "runtime_guard_service" if runtime_guard_service == null else str(runtime_guard_service.resolve_missing_dependency(owner))
	if missing_dependency.is_empty():
		return false
	if battle_result_service != null:
		battle_result_service.hard_terminate_invalid_state(
			battle_state,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			missing_dependency
		)
	else:
		_fallback_hard_terminate_invalid_state(battle_state, ErrorCodesScript.INVALID_STATE_CORRUPTION)
	return true

func _fallback_hard_terminate_invalid_state(battle_state, invalid_code: String) -> void:
	if battle_state.battle_result == null:
		return
	battle_state.battle_result.finished = true
	battle_state.battle_result.winner_side_id = null
	battle_state.battle_result.result_type = "no_winner"
	battle_state.battle_result.reason = invalid_code
	battle_state.phase = BattlePhasesScript.FINISHED
	battle_state.chain_context = null
