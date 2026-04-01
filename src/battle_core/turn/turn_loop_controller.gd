extends RefCounted
class_name TurnLoopController

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var action_queue_builder
var action_executor
var faint_resolver
var turn_resolution_service
var battle_result_service
var runtime_guard_service
var battle_logger
var log_event_builder

func run_turn(battle_state, content_index, commands: Array) -> void:
    if battle_state.battle_result.finished:
        return
    if _validate_dependencies_or_terminate(battle_state):
        return
    turn_resolution_service.reset_turn_state(battle_state)
    if _validate_runtime_or_terminate(battle_state, content_index):
        return
    if _run_turn_start_phase(battle_state, content_index):
        return
    var queue_result: Dictionary = _build_action_queue_result(battle_state, content_index, commands)
    if not bool(queue_result.get("ok", false)):
        return
    battle_state.phase = BattlePhasesScript.EXECUTION
    if _execute_action_queue(battle_state, content_index, queue_result.get("action_queue", [])):
        return
    if _run_turn_end_phase(battle_state, content_index):
        return
    _finish_turn_progression(battle_state)

func _run_turn_start_phase(battle_state, content_index) -> bool:
    battle_state.phase = BattlePhasesScript.TURN_START
    battle_state.chain_context = battle_result_service.build_system_chain(EventTypesScript.SYSTEM_TURN_START)
    var turn_start_event = log_event_builder.build_event(
        EventTypesScript.SYSTEM_TURN_START,
        battle_state,
        {
            "source_instance_id": "system:turn_start",
            "trigger_name": "turn_start",
            "payload_summary": "turn start",
        }
    )
    battle_logger.append_event(turn_start_event)
    var turn_start_event_id: String = log_event_builder.resolve_event_id(turn_start_event)
    var skip_turn_start_regen: bool = battle_state.pre_applied_turn_start_regen_turn_index == battle_state.turn_index
    if not skip_turn_start_regen:
        turn_resolution_service.apply_turn_start_regen(battle_state, turn_start_event_id)
    battle_state.pre_applied_turn_start_regen_turn_index = 0
    if turn_resolution_service.execute_system_trigger_batch("turn_start", battle_state, content_index):
        return true
    if turn_resolution_service.break_field_if_creator_inactive(battle_state, content_index):
        return true
    if turn_resolution_service.execute_matchup_changed_if_needed(battle_state, content_index):
        return true
    if turn_resolution_service.decrement_effect_instances_and_log(
        battle_state,
        content_index,
        "turn_start",
        turn_resolution_service.collect_effect_decrement_owner_ids(battle_state),
        turn_start_event_id
    ):
        return true
    turn_resolution_service.decrement_rule_mods_and_log(battle_state, "turn_start", turn_start_event_id)
    if battle_result_service.resolve_standard_victory(battle_state):
        return true
    return false

func _build_action_queue_result(battle_state, content_index, commands: Array) -> Dictionary:
    battle_state.phase = BattlePhasesScript.SELECTION
    var resolve_result = turn_resolution_service.resolve_commands_for_turn(battle_state, content_index, commands)
    if resolve_result["invalid_code"] != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(resolve_result["invalid_code"]))
        return {"ok": false}
    var locked_commands: Array = resolve_result["locked_commands"]
    if battle_result_service.resolve_surrender(battle_state, locked_commands):
        return {"ok": false}
    battle_state.phase = BattlePhasesScript.QUEUE_LOCK
    var action_queue = action_queue_builder.build_queue(locked_commands, battle_state, content_index)
    if action_queue_builder.last_invalid_battle_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(action_queue_builder.last_invalid_battle_code))
        return {"ok": false}
    return {
        "ok": true,
        "action_queue": action_queue,
    }

func _execute_action_queue(battle_state, content_index, action_queue: Array) -> bool:
    for queued_action in action_queue:
        var action_result = action_executor.execute_action(queued_action, battle_state, content_index)
        if action_result.invalid_battle_code != null:
            battle_result_service.terminate_invalid_battle(battle_state, str(action_result.invalid_battle_code))
            return true
        if _validate_runtime_or_terminate(battle_state, content_index):
            return true
        var faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
        if faint_invalid_code != null:
            battle_result_service.terminate_invalid_battle(battle_state, str(faint_invalid_code))
            return true
        if turn_resolution_service.break_field_if_creator_inactive(battle_state, content_index):
            return true
        if turn_resolution_service.execute_matchup_changed_if_needed(battle_state, content_index):
            return true
        if battle_result_service.resolve_standard_victory(battle_state):
            return true
    return false

func _run_turn_end_phase(battle_state, content_index) -> bool:
    battle_state.phase = BattlePhasesScript.TURN_END
    battle_state.chain_context = battle_result_service.build_system_chain(EventTypesScript.SYSTEM_TURN_END)
    var turn_end_event = log_event_builder.build_event(
        EventTypesScript.SYSTEM_TURN_END,
        battle_state,
        {
            "source_instance_id": "system:turn_end",
            "trigger_name": "turn_end",
            "field_change": null,
            "payload_summary": "turn end",
        }
    )
    battle_logger.append_event(turn_end_event)
    var turn_end_event_id: String = log_event_builder.resolve_event_id(turn_end_event)
    if turn_resolution_service.execute_system_trigger_batch("turn_end", battle_state, content_index):
        return true
    var field_tick_result = turn_resolution_service.apply_turn_end_field_tick(battle_state, content_index, turn_end_event_id)
    if bool(field_tick_result.get("terminated", false)):
        return true
    var field_change = field_tick_result.get("field_change", null)
    if turn_resolution_service.decrement_effect_instances_and_log(
        battle_state,
        content_index,
        "turn_end",
        turn_resolution_service.collect_effect_decrement_owner_ids(battle_state),
        turn_end_event_id
    ):
        return true
    turn_resolution_service.decrement_rule_mods_and_log(battle_state, "turn_end", turn_end_event_id)
    turn_end_event.field_change = field_change
    var turn_end_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if turn_end_faint_invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(turn_end_faint_invalid_code))
        return true
    if turn_resolution_service.break_field_if_creator_inactive(battle_state, content_index):
        return true
    if turn_resolution_service.execute_matchup_changed_if_needed(battle_state, content_index):
        return true
    if _validate_runtime_or_terminate(battle_state, content_index):
        return true
    turn_resolution_service.clear_turn_end_state(battle_state)
    return false

func _finish_turn_progression(battle_state) -> void:
    battle_state.phase = BattlePhasesScript.VICTORY_CHECK
    if battle_result_service.resolve_standard_victory(battle_state):
        return
    if battle_state.turn_index >= battle_state.max_turn:
        battle_result_service.resolve_turn_limit(battle_state)
        return
    battle_state.turn_index += 1
    battle_state.phase = BattlePhasesScript.SELECTION

func _validate_runtime_or_terminate(battle_state, content_index = null) -> bool:
    var invalid_code = runtime_guard_service.validate_runtime_state(battle_state, content_index)
    if invalid_code == null:
        return false
    battle_result_service.terminate_invalid_battle(battle_state, str(invalid_code))
    return true

func _validate_dependencies_or_terminate(battle_state) -> bool:
    var missing_dependency: String = str(runtime_guard_service.resolve_missing_dependency({
        "action_queue_builder": action_queue_builder,
        "action_executor": action_executor,
        "faint_resolver": faint_resolver,
        "turn_resolution_service": turn_resolution_service,
        "battle_result_service": battle_result_service,
    }))
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
