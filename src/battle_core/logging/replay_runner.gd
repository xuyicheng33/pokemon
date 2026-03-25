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
    var max_turn_index = battle_state.turn_index
    for command in replay_input.command_stream:
        max_turn_index = max(max_turn_index, command.turn_index)
    for turn_index in range(battle_state.turn_index, max_turn_index + 1):
        if battle_state.battle_result.finished:
            break
        var turn_commands: Array = []
        for command in replay_input.command_stream:
            if command.turn_index == turn_index:
                turn_commands.append(command)
        turn_loop_controller.run_turn(battle_state, content_index, turn_commands)
    var replay_output = ReplayOutputScript.new()
    replay_output.event_log = battle_logger.snapshot()
    replay_output.final_state_hash = _compute_state_hash(battle_state)
    replay_output.succeeded = true
    replay_output.battle_result = battle_state.battle_result
    replay_output.final_battle_state = battle_state
    return replay_output

func _compute_state_hash(battle_state) -> String:
    var json_text := JSON.stringify(battle_state.to_stable_dict())
    var hashing_context = HashingContext.new()
    hashing_context.start(HashingContext.HASH_SHA256)
    hashing_context.update(json_text.to_utf8_buffer())
    return hashing_context.finish().hex_encode()
