extends RefCounted
class_name TurnResolutionService

const EventTypesScript := preload("res://src/shared/event_types.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const SelectionStateScript := preload("res://src/battle_core/contracts/selection_state.gd")
const ValueChangeScript := preload("res://src/battle_core/contracts/value_change.gd")
const FieldChangeScript := preload("res://src/battle_core/contracts/field_change.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var legal_action_service
var command_builder
var command_validator
var mp_service
var field_service
var trigger_batch_runner
var effect_instance_dispatcher
var rule_mod_service
var faint_resolver
var battle_logger
var log_event_builder
var battle_result_service

func resolve_missing_dependency() -> String:
    if legal_action_service == null:
        return "legal_action_service"
    if command_builder == null:
        return "command_builder"
    if command_validator == null:
        return "command_validator"
    if mp_service == null:
        return "mp_service"
    if field_service == null:
        return "field_service"
    if trigger_batch_runner == null:
        return "trigger_batch_runner"
    var trigger_batch_missing := str(trigger_batch_runner.resolve_missing_dependency())
    if not trigger_batch_missing.is_empty():
        return "trigger_batch_runner.%s" % trigger_batch_missing
    if effect_instance_dispatcher == null:
        return "effect_instance_dispatcher"
    if rule_mod_service == null:
        return "rule_mod_service"
    if faint_resolver == null:
        return "faint_resolver"
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if battle_result_service == null:
        return "battle_result_service"
    return ""

func reset_turn_state(battle_state) -> void:
    for side_state in battle_state.sides:
        side_state.selection_state = SelectionStateScript.new()
        for unit_state in side_state.team_units:
            unit_state.has_acted = false

func apply_turn_start_regen(battle_state) -> void:
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

func resolve_commands_for_turn(battle_state, content_index, commands: Array) -> Dictionary:
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

func execute_system_trigger_batch(trigger_name: String, battle_state, content_index) -> bool:
    var owner_unit_ids: Array = collect_active_unit_ids(battle_state)
    var invalid_code = trigger_batch_runner.execute_trigger_batch(
        trigger_name,
        battle_state,
        content_index,
        owner_unit_ids,
        battle_state.chain_context
    )
    if invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(invalid_code))
        return true
    var faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if faint_invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(faint_invalid_code))
        return true
    if battle_result_service.resolve_standard_victory(battle_state):
        return true
    return false

func decrement_rule_mods_and_log(battle_state, trigger_name: String) -> void:
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

func decrement_effect_instances_and_log(battle_state, content_index, trigger_name: String, owner_unit_ids: Array) -> void:
    var removed_instances: Array = effect_instance_dispatcher.decrement_for_trigger(trigger_name, battle_state, content_index, owner_unit_ids)
    for removed in removed_instances:
        var removed_instance = removed["instance"]
        var effect_definition = removed["definition"]
        var log_event = log_event_builder.build_event(
            EventTypesScript.EFFECT_REMOVE_EFFECT,
            battle_state,
            {
                "source_instance_id": removed_instance.source_instance_id,
                "target_instance_id": removed["owner_id"],
                "priority": effect_definition.priority,
                "trigger_name": trigger_name,
                "payload_summary": "effect expired: %s" % effect_definition.id,
            }
        )
        log_event.cause_event_id = "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]
        battle_logger.append_event(log_event)

func apply_turn_end_field_tick(battle_state):
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

func clear_turn_end_state(battle_state) -> void:
    for side_state in battle_state.sides:
        side_state.selection_state = SelectionStateScript.new()
        for unit_state in side_state.team_units:
            unit_state.action_window_passed = false

func collect_active_unit_ids(battle_state) -> Array:
    var owner_ids: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit != null and active_unit.current_hp > 0:
            owner_ids.append(active_unit.unit_instance_id)
    return owner_ids

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
