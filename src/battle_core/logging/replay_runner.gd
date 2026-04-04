extends RefCounted
class_name ReplayRunner

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const ReplayOutputScript := preload("res://src/battle_core/contracts/replay_output.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_initializer
var turn_loop_controller
var battle_logger
var id_factory
var rng_service
var content_snapshot_cache
var last_error_code: Variant = null
var last_error_message: String = ""

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

func run_replay(replay_input):
    return run_replay_with_context(replay_input).get("replay_output", null)

func run_replay_with_context(replay_input) -> Dictionary:
    last_error_code = null
    last_error_message = ""
    var missing_dependency := resolve_missing_dependency()
    if not missing_dependency.is_empty():
        return _fail("ReplayRunner missing dependency: %s" % missing_dependency, ErrorCodesScript.INVALID_COMPOSITION)
    if replay_input == null:
        return _fail("Replay input is required")
    if replay_input.battle_setup == null:
        return _fail("Replay battle setup is required")
    id_factory.reset()
    var content_index_result = content_snapshot_cache.build_content_index(replay_input.content_snapshot_paths)
    if not bool(content_index_result.get("ok", false)):
        last_error_code = content_index_result.get("error_code", ErrorCodesScript.INVALID_CONTENT_SNAPSHOT)
        last_error_message = String(content_index_result.get("error_message", "ReplayRunner failed to load content snapshot"))
        return {"replay_output": null, "content_index": null}
    var content_index = content_index_result.get("content_index", null)
    rng_service.reset(replay_input.battle_seed)
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = id_factory.next_id("battle")
    battle_state.seed = replay_input.battle_seed
    battle_state.rng_stream_index = rng_service.get_stream_index()
    if not battle_initializer.initialize_battle(battle_state, content_index, replay_input.battle_setup):
        var initializer_error_state: Dictionary = battle_initializer.error_state()
        last_error_code = initializer_error_state.get("code", ErrorCodesScript.INVALID_BATTLE_SETUP)
        last_error_message = String(initializer_error_state.get("message", "ReplayRunner failed to initialize battle"))
        return {"replay_output": null, "content_index": content_index}
    var max_turn_index: int = battle_state.max_turn if battle_state.max_turn > 0 else battle_state.turn_index
    var commands_by_turn: Dictionary = _group_commands_by_turn(replay_input.command_stream)
    while not battle_state.battle_result.finished and battle_state.turn_index <= max_turn_index:
        var turn_commands: Array = commands_by_turn.get(battle_state.turn_index, [])
        turn_loop_controller.run_turn(battle_state, content_index, turn_commands)
    var replay_output = ReplayOutputScript.new()
    replay_output.event_log = battle_logger.snapshot()
    replay_output.final_state_hash = _compute_state_hash(battle_state)
    var run_completed: bool = battle_state.battle_result != null and battle_state.battle_result.finished
    replay_output.succeeded = run_completed and _validate_log_schema_v3(replay_output.event_log) and _validate_battle_result(battle_state.battle_result)
    replay_output.battle_result = battle_state.battle_result
    replay_output.final_battle_state = battle_state
    return {
        "replay_output": replay_output,
        "content_index": content_index,
    }

func _fail(message: String, error_code: String = ErrorCodesScript.INVALID_REPLAY_INPUT) -> Dictionary:
    last_error_code = error_code
    last_error_message = message
    return {"replay_output": null, "content_index": null}

func _group_commands_by_turn(command_stream: Array) -> Dictionary:
    var commands_by_turn: Dictionary = {}
    for command in command_stream:
        if command == null:
            continue
        var turn_index: int = int(command.turn_index)
        if not commands_by_turn.has(turn_index):
            commands_by_turn[turn_index] = []
        commands_by_turn[turn_index].append(command)
    return commands_by_turn

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
