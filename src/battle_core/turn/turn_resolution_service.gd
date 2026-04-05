extends RefCounted
class_name TurnResolutionService

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ValueChangeFactoryScript := preload("res://src/battle_core/contracts/value_change_factory.gd")

var selection_resolver
var field_lifecycle_service
var mp_service
var trigger_batch_runner
var effect_instance_dispatcher
var rule_mod_service
var faint_resolver
var battle_logger
var log_event_builder
var battle_result_service

func resolve_missing_dependency() -> String:
    if selection_resolver == null:
        return "selection_resolver"
    var selection_missing := str(selection_resolver.resolve_missing_dependency())
    if not selection_missing.is_empty():
        return "selection_resolver.%s" % selection_missing
    if field_lifecycle_service == null:
        return "field_lifecycle_service"
    var lifecycle_missing := str(field_lifecycle_service.resolve_missing_dependency())
    if not lifecycle_missing.is_empty():
        return "field_lifecycle_service.%s" % lifecycle_missing
    if mp_service == null:
        return "mp_service"
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
    selection_resolver.reset_turn_state(battle_state)

func apply_turn_start_regen(battle_state, cause_event_id: String) -> void:
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null or active_unit.current_hp <= 0:
            continue
        var before_mp: int = active_unit.current_mp
        var regen_value: int = rule_mod_service.resolve_mp_regen_value(battle_state, active_unit.unit_instance_id, active_unit.regen_per_turn)
        active_unit.current_mp = mp_service.apply_turn_start_regen(active_unit.current_mp, regen_value, active_unit.max_mp)
        if before_mp == active_unit.current_mp:
            continue
        var value_change = ValueChangeFactoryScript.create(
            active_unit.unit_instance_id,
            "mp",
            before_mp,
            active_unit.current_mp
        )
        var log_event = log_event_builder.build_effect_event(
            EventTypesScript.EFFECT_RESOURCE_MOD,
            battle_state,
            cause_event_id,
            {
                "source_instance_id": "system:turn_start",
                "target_instance_id": active_unit.unit_instance_id,
                "trigger_name": "turn_start",
                "value_changes": [value_change],
                "payload_summary": "%s regenerated %d mp" % [active_unit.public_id, value_change.delta],
            }
        )
        battle_logger.append_event(log_event)

func resolve_commands_for_turn(battle_state, content_index, commands: Array) -> Dictionary:
    return selection_resolver.resolve_commands_for_turn(battle_state, content_index, commands)

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

func decrement_rule_mods_and_log(battle_state, trigger_name: String, cause_event_id: String) -> void:
    var removed_instances: Array = rule_mod_service.decrement_for_trigger(battle_state, trigger_name)
    for removed in removed_instances:
        var removed_instance = removed["instance"]
        var log_event = log_event_builder.build_effect_event(
            EventTypesScript.EFFECT_RULE_MOD_REMOVE,
            battle_state,
            cause_event_id,
            {
                "source_instance_id": removed_instance.instance_id,
                "target_instance_id": removed["owner_id"],
                "priority": removed_instance.priority,
                "trigger_name": trigger_name,
                "payload_summary": "rule mod expired: %s" % removed_instance.mod_kind,
            }
        )
        battle_logger.append_event(log_event)

func decrement_effect_instances_and_log(battle_state, content_index, trigger_name: String, owner_unit_ids: Array, cause_event_id: String) -> bool:
    var decrement_result: Dictionary = effect_instance_dispatcher.decrement_for_trigger(trigger_name, battle_state, content_index, owner_unit_ids)
    var decrement_invalid_code = decrement_result.get("invalid_code", null)
    if decrement_invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(decrement_invalid_code))
        return true
    var removed_instances: Array = decrement_result.get("removed_instances", [])
    var expire_events: Array = decrement_result.get("expire_events", [])
    if not expire_events.is_empty():
        var expire_invalid_code = trigger_batch_runner.execute_trigger_batch(
            "__effect_expire__",
            battle_state,
            content_index,
            [],
            battle_state.chain_context,
            expire_events
        )
        if expire_invalid_code != null:
            battle_result_service.terminate_invalid_battle(battle_state, str(expire_invalid_code))
            return true
    for removed in removed_instances:
        var removed_instance = removed["instance"]
        var effect_definition = removed["definition"]
        var log_event = log_event_builder.build_effect_event(
            EventTypesScript.EFFECT_REMOVE_EFFECT,
            battle_state,
            cause_event_id,
            {
                "source_instance_id": removed_instance.source_instance_id,
                "target_instance_id": removed["owner_id"],
                "priority": effect_definition.priority,
                "trigger_name": trigger_name,
                "payload_summary": "effect expired: %s" % effect_definition.id,
            }
        )
        battle_logger.append_event(log_event)
    return false

func apply_turn_end_field_tick(battle_state, content_index, cause_event_id: String):
    return field_lifecycle_service.apply_turn_end_field_tick(battle_state, content_index, cause_event_id)

func clear_turn_end_state(battle_state) -> void:
    selection_resolver.clear_turn_end_state(battle_state)

func collect_active_unit_ids(battle_state) -> Array:
    return field_lifecycle_service.collect_active_unit_ids(battle_state)

func collect_effect_decrement_owner_ids(battle_state) -> Array:
    var owner_ids: Array = collect_active_unit_ids(battle_state)
    var seen_owner_ids: Dictionary = {}
    for owner_id in owner_ids:
        seen_owner_ids[str(owner_id)] = true
    for side_state in battle_state.sides:
        for unit_state in side_state.team_units:
            if unit_state == null:
                continue
            var unit_id := String(unit_state.unit_instance_id)
            if seen_owner_ids.has(unit_id):
                continue
            if not _unit_has_persistent_effect(unit_state):
                continue
            owner_ids.append(unit_id)
            seen_owner_ids[unit_id] = true
    return owner_ids

func _unit_has_persistent_effect(unit_state) -> bool:
    if unit_state == null:
        return false
    for effect_instance in unit_state.effect_instances:
        if bool(effect_instance.persists_on_switch):
            return true
    return false

func execute_matchup_changed_if_needed(battle_state, content_index) -> bool:
    return field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index)

func break_field_if_creator_inactive(battle_state, content_index) -> bool:
    return field_lifecycle_service.break_field_if_creator_inactive(battle_state, content_index)

func break_active_field(battle_state, content_index, trigger_name: String) -> bool:
    return field_lifecycle_service.break_active_field(battle_state, content_index, trigger_name)
