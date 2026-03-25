extends RefCounted
class_name ReplayRunner

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const ReplayOutputScript := preload("res://src/battle_core/contracts/replay_output.gd")

var battle_initializer
var turn_loop_controller
var battle_logger
var id_factory
var rng_service

func run_replay(replay_input):
    assert(replay_input != null, "Replay input is required")
    assert(replay_input.battle_setup != null, "Replay battle setup is required")
    id_factory.reset()
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(replay_input.content_snapshot_paths)
    rng_service.reset(replay_input.battle_seed)
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = id_factory.next_id("battle")
    battle_state.seed = replay_input.battle_seed
    battle_state.rng_stream_index = rng_service.get_stream_index()
    battle_initializer.initialize_battle(battle_state, content_index, replay_input.battle_setup)
    var max_turn_index: int = battle_state.max_turn if battle_state.max_turn > 0 else battle_state.turn_index
    while not battle_state.battle_result.finished and battle_state.turn_index <= max_turn_index:
        var turn_commands: Array = []
        for command in replay_input.command_stream:
            if command.turn_index == battle_state.turn_index:
                turn_commands.append(command)
        turn_loop_controller.run_turn(battle_state, content_index, turn_commands)
    var replay_output = ReplayOutputScript.new()
    replay_output.event_log = battle_logger.snapshot()
    replay_output.final_state_hash = _compute_state_hash(battle_state)
    var run_completed: bool = battle_state.battle_result != null and battle_state.battle_result.finished
    replay_output.succeeded = run_completed and _validate_log_schema_v2(replay_output.event_log) and _validate_battle_result(battle_state.battle_result)
    replay_output.battle_result = battle_state.battle_result
    replay_output.final_battle_state = battle_state
    return replay_output

func _compute_state_hash(battle_state) -> String:
    var json_text := JSON.stringify(battle_state.to_stable_dict())
    var hashing_context = HashingContext.new()
    hashing_context.start(HashingContext.HASH_SHA256)
    hashing_context.update(json_text.to_utf8_buffer())
    return hashing_context.finish().hex_encode()

func _validate_log_schema_v2(event_log: Array) -> bool:
    for log_event in event_log:
        if log_event == null:
            return false
        if int(log_event.log_schema_version) != 2:
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
        if String(log_event.event_type).begins_with("effect:"):
            if log_event.trigger_name == null:
                return false
            if log_event.cause_event_id == null:
                return false
    return true

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
