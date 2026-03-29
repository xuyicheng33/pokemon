extends RefCounted
class_name ReplayOutput

var event_log: Array = []
var final_state_hash: String = ""
var succeeded: bool = false
var battle_result = null
var final_battle_state = null

func clone_without_runtime_state():
    var replay_output = get_script().new()
    replay_output.event_log = event_log.duplicate()
    replay_output.final_state_hash = final_state_hash
    replay_output.succeeded = succeeded
    replay_output.battle_result = battle_result
    replay_output.final_battle_state = null
    return replay_output
