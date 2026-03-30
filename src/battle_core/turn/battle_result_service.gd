extends RefCounted
class_name BattleResultService

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")

var id_factory
var battle_logger
var log_event_builder

func resolve_missing_dependency() -> String:
    if id_factory == null:
        return "id_factory"
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    return ""

func build_system_chain(command_type: String):
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = id_factory.next_id("chain")
    chain_context.chain_origin = _resolve_chain_origin(command_type)
    chain_context.command_type = command_type
    chain_context.command_source = "system"
    chain_context.select_deadline_ms = null
    chain_context.select_timeout = null
    return chain_context

func terminate_invalid_battle(battle_state, invalid_code: String) -> void:
    _report_invalid_termination(
        "BattleResultService terminate_invalid_battle: battle_id=%s phase=%s invalid_code=%s" % [
            str(battle_state.battle_id),
            str(battle_state.phase),
            invalid_code,
        ]
    )
    battle_state.battle_result.finished = true
    battle_state.battle_result.winner_side_id = null
    battle_state.battle_result.result_type = "no_winner"
    battle_state.battle_result.reason = invalid_code
    battle_state.phase = BattlePhasesScript.FINISHED
    battle_state.chain_context = build_system_chain(EventTypesScript.SYSTEM_INVALID_BATTLE)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_INVALID_BATTLE,
        battle_state,
        {
            "source_instance_id": "system:invalid_battle",
            "invalid_battle_code": invalid_code,
            "payload_summary": "invalid battle: %s" % invalid_code,
        }
    ))

func hard_terminate_invalid_state(battle_state, invalid_code: String, missing_dependency: String) -> void:
    _report_invalid_termination(
        "BattleResultService hard_terminate_invalid_state: battle_id=%s phase=%s invalid_code=%s missing_dependency=%s" % [
            str(battle_state.battle_id),
            str(battle_state.phase),
            invalid_code,
            missing_dependency,
        ]
    )
    if battle_state.battle_result == null:
        return
    battle_state.battle_result.finished = true
    battle_state.battle_result.winner_side_id = null
    battle_state.battle_result.result_type = "no_winner"
    battle_state.battle_result.reason = invalid_code
    battle_state.phase = BattlePhasesScript.FINISHED
    if id_factory == null or battle_logger == null or log_event_builder == null:
        battle_state.chain_context = null
        return
    battle_state.chain_context = build_system_chain(EventTypesScript.SYSTEM_INVALID_BATTLE)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_INVALID_BATTLE,
        battle_state,
        {
            "source_instance_id": "system:invalid_battle",
            "invalid_battle_code": invalid_code,
            "payload_summary": "invalid battle: %s (missing dependency: %s)" % [invalid_code, missing_dependency],
        }
    ))

func resolve_surrender(battle_state, commands: Array) -> bool:
    var surrendering_sides: Array = []
    for command in commands:
        if command.command_type == CommandTypesScript.SURRENDER:
            surrendering_sides.append(command.side_id)
    if surrendering_sides.is_empty():
        return false
    var resolved_phase: String = battle_state.phase
    battle_state.battle_result.finished = true
    battle_state.phase = BattlePhasesScript.FINISHED
    if surrendering_sides.size() == 1:
        var winner_side = battle_state.get_opponent_side(surrendering_sides[0])
        battle_state.battle_result.winner_side_id = winner_side.side_id if winner_side != null else null
        battle_state.battle_result.result_type = "win"
    else:
        battle_state.battle_result.winner_side_id = null
        battle_state.battle_result.result_type = "draw"
    battle_state.battle_result.reason = "surrender"
    battle_state.chain_context = _build_battle_end_chain(resolved_phase, battle_state)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.RESULT_BATTLE_END,
        battle_state,
        {
            "source_instance_id": "system:battle_end",
            "payload_summary": "battle ended by surrender",
        }
    ))
    return true

func resolve_standard_victory(battle_state) -> bool:
    var alive_side_ids: Array = []
    for side_state in battle_state.sides:
        if _side_has_available_unit(side_state):
            alive_side_ids.append(side_state.side_id)
    if alive_side_ids.size() == battle_state.sides.size():
        return false
    var resolved_phase: String = battle_state.phase
    battle_state.battle_result.finished = true
    battle_state.phase = BattlePhasesScript.FINISHED
    if alive_side_ids.is_empty():
        battle_state.battle_result.winner_side_id = null
        battle_state.battle_result.result_type = "draw"
        battle_state.battle_result.reason = "double_faint"
    else:
        battle_state.battle_result.winner_side_id = alive_side_ids[0]
        battle_state.battle_result.result_type = "win"
        battle_state.battle_result.reason = "elimination"
    battle_state.chain_context = _build_battle_end_chain(resolved_phase, battle_state)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.RESULT_BATTLE_END,
        battle_state,
        {
            "source_instance_id": "system:battle_end",
            "payload_summary": "battle finished by elimination",
        }
    ))
    return true

func resolve_turn_limit(battle_state) -> void:
    var scored_sides: Array = []
    for side_state in battle_state.sides:
        var available_count: int = 0
        var current_hp_total: int = 0
        var max_hp_total: int = 0
        for unit_state in side_state.team_units:
            if unit_state.current_hp > 0:
                available_count += 1
            current_hp_total += unit_state.current_hp
            max_hp_total += unit_state.max_hp
        scored_sides.append({
            "side_id": side_state.side_id,
            "available_count": available_count,
            "current_hp_total": current_hp_total,
            "max_hp_total": max_hp_total,
        })
    scored_sides.sort_custom(_sort_turn_limit_scores)
    battle_state.battle_result.finished = true
    battle_state.phase = BattlePhasesScript.FINISHED
    if scored_sides.size() > 1 and _turn_limit_scores_equal(scored_sides[0], scored_sides[1]):
        battle_state.battle_result.winner_side_id = null
        battle_state.battle_result.result_type = "draw"
    else:
        battle_state.battle_result.winner_side_id = scored_sides[0]["side_id"]
        battle_state.battle_result.result_type = "win"
    battle_state.battle_result.reason = "turn_limit"
    battle_state.chain_context = build_system_chain(EventTypesScript.SYSTEM_TURN_LIMIT)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_TURN_LIMIT,
        battle_state,
        {
            "source_instance_id": "system:turn_limit",
            "payload_summary": "turn limit resolved",
        }
    ))
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.RESULT_BATTLE_END,
        battle_state,
        {
            "source_instance_id": "system:battle_end",
            "payload_summary": "battle ended by turn limit",
        }
    ))

func _sort_turn_limit_scores(left: Dictionary, right: Dictionary) -> bool:
    if left["available_count"] != right["available_count"]:
        return left["available_count"] > right["available_count"]
    var left_cross: int = int(left["current_hp_total"]) * int(right["max_hp_total"])
    var right_cross: int = int(right["current_hp_total"]) * int(left["max_hp_total"])
    if left_cross != right_cross:
        return left_cross > right_cross
    if left["current_hp_total"] != right["current_hp_total"]:
        return left["current_hp_total"] > right["current_hp_total"]
    return left["side_id"] < right["side_id"]

func _turn_limit_scores_equal(left: Dictionary, right: Dictionary) -> bool:
    return left["available_count"] == right["available_count"] \
    and left["current_hp_total"] * right["max_hp_total"] == right["current_hp_total"] * left["max_hp_total"] \
    and left["current_hp_total"] == right["current_hp_total"]

func _side_has_available_unit(side_state) -> bool:
    for unit_state in side_state.team_units:
        if unit_state.current_hp > 0:
            return true
    return false

func _build_battle_end_chain(resolved_phase: String, battle_state):
    match resolved_phase:
        BattlePhasesScript.BATTLE_INIT:
            return build_system_chain(EventTypesScript.SYSTEM_BATTLE_INIT)
        BattlePhasesScript.TURN_START:
            return build_system_chain(EventTypesScript.SYSTEM_TURN_START)
        BattlePhasesScript.TURN_END, BattlePhasesScript.VICTORY_CHECK:
            return build_system_chain(EventTypesScript.SYSTEM_TURN_END)
        _:
            return build_system_chain("system:replace")

func _resolve_chain_origin(command_type: String) -> String:
    match command_type:
        EventTypesScript.SYSTEM_BATTLE_INIT:
            return "battle_init"
        EventTypesScript.SYSTEM_TURN_START:
            return "turn_start"
        EventTypesScript.SYSTEM_TURN_END, EventTypesScript.SYSTEM_TURN_LIMIT:
            return "turn_end"
        _:
            return "system_replace"

func _report_invalid_termination(message: String) -> void:
    printerr("INVALID_TERMINATION: %s" % message)
