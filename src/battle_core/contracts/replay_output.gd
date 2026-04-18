extends RefCounted
class_name ReplayOutput

var event_log: Array = []
var turn_timeline: Array = []
var final_state_hash: String = ""
var succeeded: bool = false
var failure_code: String = ""
var failure_message: String = ""
var battle_result = null
var final_battle_state = null

func clone_without_runtime_state() -> Variant:
	var replay_output = get_script().new()
	replay_output.event_log = event_log.duplicate()
	replay_output.turn_timeline = turn_timeline.duplicate(true)
	replay_output.final_state_hash = final_state_hash
	replay_output.succeeded = succeeded
	replay_output.failure_code = failure_code
	replay_output.failure_message = failure_message
	replay_output.battle_result = battle_result
	replay_output.final_battle_state = null
	return replay_output
