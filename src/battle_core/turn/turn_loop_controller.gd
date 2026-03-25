extends RefCounted
class_name TurnLoopController

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const SelectionStateScript := preload("res://src/battle_core/contracts/selection_state.gd")
const ValueChangeScript := preload("res://src/battle_core/contracts/value_change.gd")
const FieldChangeScript := preload("res://src/battle_core/contracts/field_change.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var id_factory
var legal_action_service
var command_builder
var command_validator
var action_queue_builder
var action_executor
var faint_resolver
var mp_service
var field_service
var passive_skill_service
var passive_item_service
var effect_queue_service
var payload_executor
var rule_mod_service
var rng_service
var battle_logger
var log_event_builder

func run_turn(battle_state, content_index, commands: Array) -> void:
    if battle_state.battle_result.finished:
        return
    _reset_turn_state(battle_state)
    if _validate_runtime_or_terminate(battle_state):
        return
    battle_state.phase = BattlePhasesScript.TURN_START
    battle_state.chain_context = _build_system_chain(EventTypesScript.SYSTEM_TURN_START, battle_state)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_TURN_START,
        battle_state,
        {
            "source_instance_id": "system:turn_start",
            "trigger_name": "turn_start",
            "payload_summary": "turn start",
        }
    ))
    _apply_turn_start_regen(battle_state)
    if _execute_system_trigger_batch("turn_start", battle_state, content_index):
        return
    _decrement_rule_mods_and_log(battle_state, "turn_start")
    if _resolve_standard_victory(battle_state):
        return

    battle_state.phase = BattlePhasesScript.SELECTION
    var resolve_result = _resolve_commands_for_turn(battle_state, content_index, commands)
    if resolve_result["invalid_code"] != null:
        _terminate_invalid_battle(battle_state, str(resolve_result["invalid_code"]))
        return
    var locked_commands: Array = resolve_result["locked_commands"]
    if _resolve_surrender(battle_state, locked_commands):
        return

    battle_state.phase = BattlePhasesScript.QUEUE_LOCK
    var action_queue = action_queue_builder.build_queue(locked_commands, battle_state, content_index)
    battle_state.phase = BattlePhasesScript.EXECUTION
    for queued_action in action_queue:
        var action_result = action_executor.execute_action(queued_action, battle_state, content_index)
        if action_result.invalid_battle_code != null:
            _terminate_invalid_battle(battle_state, str(action_result.invalid_battle_code))
            return
        if _validate_runtime_or_terminate(battle_state):
            return
        var faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
        if faint_invalid_code != null:
            _terminate_invalid_battle(battle_state, str(faint_invalid_code))
            return
        if _resolve_standard_victory(battle_state):
            return

    battle_state.phase = BattlePhasesScript.TURN_END
    battle_state.chain_context = _build_system_chain(EventTypesScript.SYSTEM_TURN_END, battle_state)
    if _execute_system_trigger_batch("turn_end", battle_state, content_index):
        return
    var field_change = _apply_turn_end_field_tick(battle_state)
    _decrement_rule_mods_and_log(battle_state, "turn_end")
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_TURN_END,
        battle_state,
        {
            "source_instance_id": "system:turn_end",
            "trigger_name": "turn_end",
            "field_change": field_change,
            "payload_summary": "turn end",
        }
    ))
    var turn_end_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if turn_end_faint_invalid_code != null:
        _terminate_invalid_battle(battle_state, str(turn_end_faint_invalid_code))
        return
    if _validate_runtime_or_terminate(battle_state):
        return
    _clear_turn_end_state(battle_state)

    battle_state.phase = BattlePhasesScript.VICTORY_CHECK
    if _resolve_standard_victory(battle_state):
        return
    if battle_state.turn_index >= battle_state.max_turn:
        _resolve_turn_limit(battle_state)
        return
    battle_state.turn_index += 1
    battle_state.phase = BattlePhasesScript.SELECTION

func _reset_turn_state(battle_state) -> void:
    for side_state in battle_state.sides:
        side_state.selection_state = SelectionStateScript.new()
        for unit_state in side_state.team_units:
            unit_state.has_acted = false

func _apply_turn_start_regen(battle_state) -> void:
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null or active_unit.current_hp <= 0:
            continue
        var before_mp: int = active_unit.current_mp
        var regen_value: int = rule_mod_service.resolve_mp_regen_value(battle_state, active_unit.unit_instance_id, active_unit.regen_per_turn)
        active_unit.current_mp = mp_service.apply_turn_start_regen(active_unit.current_mp, regen_value, active_unit.max_mp)
        if before_mp == active_unit.current_mp:
            continue
        var value_change = ValueChangeScript.new()
        value_change.entity_id = active_unit.unit_instance_id
        value_change.resource_name = "mp"
        value_change.before_value = before_mp
        value_change.after_value = active_unit.current_mp
        value_change.delta = active_unit.current_mp - before_mp
        var log_event = log_event_builder.build_event(
            EventTypesScript.EFFECT_RESOURCE_MOD,
            battle_state,
            {
                "source_instance_id": "system:turn_start",
                "target_instance_id": active_unit.unit_instance_id,
                "trigger_name": "turn_start",
                "value_changes": [value_change],
                "payload_summary": "%s regenerated %d mp" % [active_unit.public_id, value_change.delta],
            }
        )
        log_event.cause_event_id = "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]
        battle_logger.append_event(log_event)

func _resolve_commands_for_turn(battle_state, content_index, commands: Array) -> Dictionary:
    var allowed_side_ids: Dictionary = {}
    for side_state in battle_state.sides:
        allowed_side_ids[side_state.side_id] = true
    var commands_by_side: Dictionary = {}
    for command in commands:
        if command == null or not allowed_side_ids.has(command.side_id):
            return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
        if commands_by_side.has(command.side_id):
            return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
        commands_by_side[command.side_id] = command
    var locked_commands: Array = []
    for side_state in battle_state.sides:
        var legal_action_set = legal_action_service.get_legal_actions(battle_state, side_state.side_id, content_index)
        var provided_command = commands_by_side.get(side_state.side_id, null)
        var resolved_command = null
        if provided_command != null and provided_command.command_type == CommandTypesScript.SURRENDER:
            resolved_command = provided_command
        elif not legal_action_set.forced_command_type.is_empty():
            if provided_command != null:
                return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
            resolved_command = command_builder.build_command({
                "turn_index": battle_state.turn_index,
                "command_type": CommandTypesScript.RESOURCE_FORCED_DEFAULT,
                "command_source": "resource_auto",
                "side_id": side_state.side_id,
                "actor_id": legal_action_set.actor_id,
            })
        elif provided_command == null:
            resolved_command = command_builder.build_command({
                "turn_index": battle_state.turn_index,
                "command_type": CommandTypesScript.TIMEOUT_DEFAULT,
                "command_source": "timeout_auto",
                "side_id": side_state.side_id,
                "actor_id": legal_action_set.actor_id,
            })
        else:
            if not command_validator.validate_command(provided_command, battle_state, content_index):
                return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
            if not _is_command_in_legal_set(provided_command, legal_action_set):
                return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
            resolved_command = provided_command
        side_state.selection_state.selected_command = resolved_command
        side_state.selection_state.selection_locked = true
        side_state.selection_state.timed_out = resolved_command.command_type == CommandTypesScript.TIMEOUT_DEFAULT
        locked_commands.append(resolved_command)
    return {"locked_commands": locked_commands, "invalid_code": null}

func _execute_system_trigger_batch(trigger_name: String, battle_state, content_index) -> bool:
    var owner_unit_ids: Array = _collect_active_unit_ids(battle_state)
    var effect_events: Array = []
    effect_events.append_array(passive_skill_service.collect_trigger_events(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context))
    effect_events.append_array(passive_item_service.collect_trigger_events(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context))
    effect_events.append_array(field_service.collect_trigger_events(trigger_name, battle_state, content_index, battle_state.chain_context))
    if effect_events.is_empty():
        return false
    battle_state.pending_effect_queue = effect_events
    var sorted_events = effect_queue_service.sort_events(effect_events, rng_service)
    if rng_service != null:
        battle_state.rng_stream_index = rng_service.get_stream_index()
    for effect_event in sorted_events:
        payload_executor.execute_effect_event(effect_event, battle_state, content_index)
        if payload_executor.last_invalid_battle_code != null:
            _terminate_invalid_battle(battle_state, str(payload_executor.last_invalid_battle_code))
            battle_state.pending_effect_queue.clear()
            return true
    battle_state.pending_effect_queue.clear()
    var faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if faint_invalid_code != null:
        _terminate_invalid_battle(battle_state, str(faint_invalid_code))
        return true
    if _resolve_standard_victory(battle_state):
        return true
    return false

func _decrement_rule_mods_and_log(battle_state, trigger_name: String) -> void:
    var removed_instances: Array = rule_mod_service.decrement_for_trigger(battle_state, trigger_name)
    for removed in removed_instances:
        var removed_instance = removed["instance"]
        var log_event = log_event_builder.build_event(
            EventTypesScript.EFFECT_RULE_MOD_REMOVE,
            battle_state,
            {
                "source_instance_id": removed_instance.instance_id,
                "target_instance_id": removed["owner_id"],
                "priority": removed_instance.priority,
                "trigger_name": trigger_name,
                "payload_summary": "rule mod expired: %s" % removed_instance.mod_kind,
            }
        )
        log_event.cause_event_id = "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]
        battle_logger.append_event(log_event)

func _apply_turn_end_field_tick(battle_state):
    if battle_state.field_state == null:
        return null
    var field_change = FieldChangeScript.new()
    field_change.change_kind = "tick"
    field_change.before_field_id = battle_state.field_state.field_def_id
    field_change.before_remaining_turns = battle_state.field_state.remaining_turns
    var expired: bool = field_service.tick_turn_end(battle_state.field_state)
    field_change.after_field_id = battle_state.field_state.field_def_id if not expired else null
    field_change.after_remaining_turns = battle_state.field_state.remaining_turns if not expired else 0
    if expired:
        var log_event = log_event_builder.build_event(
            EventTypesScript.EFFECT_FIELD_EXPIRE,
            battle_state,
            {
                "source_instance_id": battle_state.field_state.instance_id,
                "trigger_name": "turn_end",
                "field_change": field_change,
                "payload_summary": "field expired",
            }
        )
        log_event.cause_event_id = "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]
        battle_logger.append_event(log_event)
        battle_state.field_state = null
    return field_change

func _clear_turn_end_state(battle_state) -> void:
    for side_state in battle_state.sides:
        side_state.selection_state = SelectionStateScript.new()
        for unit_state in side_state.team_units:
            unit_state.action_window_passed = false

func _resolve_surrender(battle_state, commands: Array) -> bool:
    var surrendering_sides: Array = []
    for command in commands:
        if command.command_type == CommandTypesScript.SURRENDER:
            surrendering_sides.append(command.side_id)
    if surrendering_sides.is_empty():
        return false
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
    battle_state.chain_context = _build_system_chain(EventTypesScript.RESULT_BATTLE_END, battle_state)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.RESULT_BATTLE_END,
        battle_state,
        {
            "source_instance_id": "system:battle_end",
            "payload_summary": "battle ended by surrender",
        }
    ))
    return true

func _resolve_standard_victory(battle_state) -> bool:
    var alive_side_ids: Array = []
    for side_state in battle_state.sides:
        if _side_has_available_unit(side_state):
            alive_side_ids.append(side_state.side_id)
    if alive_side_ids.size() == battle_state.sides.size():
        return false
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
    battle_state.chain_context = _build_system_chain(EventTypesScript.RESULT_BATTLE_END, battle_state)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.RESULT_BATTLE_END,
        battle_state,
        {
            "source_instance_id": "system:battle_end",
            "payload_summary": "battle finished by elimination",
        }
    ))
    return true

func _resolve_turn_limit(battle_state) -> void:
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
    battle_state.chain_context = _build_system_chain(EventTypesScript.SYSTEM_TURN_LIMIT, battle_state)
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

func _collect_active_unit_ids(battle_state) -> Array:
    var owner_ids: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit != null and active_unit.current_hp > 0:
            owner_ids.append(active_unit.unit_instance_id)
    return owner_ids

func _terminate_invalid_battle(battle_state, invalid_code: String) -> void:
    battle_state.battle_result.finished = true
    battle_state.battle_result.winner_side_id = null
    battle_state.battle_result.result_type = "no_winner"
    battle_state.battle_result.reason = invalid_code
    battle_state.phase = BattlePhasesScript.FINISHED
    battle_state.chain_context = _build_system_chain(EventTypesScript.SYSTEM_INVALID_BATTLE, battle_state)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_INVALID_BATTLE,
        battle_state,
        {
            "source_instance_id": "system:invalid_battle",
            "invalid_battle_code": invalid_code,
            "payload_summary": "invalid battle: %s" % invalid_code,
        }
    ))

func _build_system_chain(command_type: String, _battle_state):
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = id_factory.next_id("chain")
    chain_context.chain_origin = _resolve_chain_origin(command_type)
    chain_context.command_type = command_type
    chain_context.command_source = "system"
    chain_context.select_deadline_ms = null
    chain_context.select_timeout = null
    return chain_context

func _resolve_chain_origin(command_type: String) -> String:
    match command_type:
        EventTypesScript.SYSTEM_BATTLE_INIT:
            return "battle_init"
        EventTypesScript.SYSTEM_TURN_START:
            return "turn_start"
        EventTypesScript.SYSTEM_TURN_END:
            return "turn_end"
        _:
            return "system_replace"

func _is_command_in_legal_set(command, legal_action_set) -> bool:
    match command.command_type:
        CommandTypesScript.SKILL:
            return legal_action_set.legal_skill_ids.has(command.skill_id)
        CommandTypesScript.ULTIMATE:
            return legal_action_set.legal_ultimate_ids.has(command.skill_id)
        CommandTypesScript.SWITCH:
            return legal_action_set.legal_switch_target_ids.has(command.target_unit_id)
        CommandTypesScript.SURRENDER:
            return true
        _:
            return false

func _validate_runtime_or_terminate(battle_state) -> bool:
    var invalid_code = _validate_runtime_state(battle_state)
    if invalid_code == null:
        return false
    _terminate_invalid_battle(battle_state, str(invalid_code))
    return true

func _validate_runtime_state(battle_state):
    if battle_state.max_chain_depth <= 0:
        return ErrorCodesScript.INVALID_STATE_CORRUPTION
    for side_state in battle_state.sides:
        for unit_state in side_state.team_units:
            if unit_state.max_hp <= 0 or unit_state.max_mp < 0:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
            if unit_state.current_hp < 0 or unit_state.current_hp > unit_state.max_hp:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
            if unit_state.current_mp < 0 or unit_state.current_mp > unit_state.max_mp:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
        for slot_id in side_state.active_slots.keys():
            var active_unit_id: String = str(side_state.active_slots[slot_id])
            if active_unit_id.is_empty() or side_state.find_unit(active_unit_id) == null:
                return ErrorCodesScript.INVALID_STATE_CORRUPTION
    if battle_state.field_state != null and battle_state.field_state.remaining_turns < 0:
        return ErrorCodesScript.INVALID_STATE_CORRUPTION
    return null
