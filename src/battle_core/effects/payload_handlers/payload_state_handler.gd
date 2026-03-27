extends RefCounted
class_name PayloadStateHandler

const EventTypesScript := preload("res://src/shared/event_types.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const FieldChangeScript := preload("res://src/battle_core/contracts/field_change.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_logger
var log_event_builder
var id_factory
var effect_instance_service
var rule_mod_service
var rule_mod_value_resolver
var field_service
var trigger_batch_runner

var last_invalid_battle_code: Variant = null

func resolve_missing_dependency() -> String:
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if id_factory == null:
        return "id_factory"
    if effect_instance_service == null:
        return "effect_instance_service"
    if rule_mod_service == null:
        return "rule_mod_service"
    if rule_mod_value_resolver == null:
        return "rule_mod_value_resolver"
    if field_service == null:
        return "field_service"
    if trigger_batch_runner == null:
        return "trigger_batch_runner"
    return ""

func execute(payload, effect_definition, effect_event, battle_state, content_index) -> bool:
    last_invalid_battle_code = null
    if payload is ApplyFieldPayloadScript:
        _apply_field_payload(payload, effect_definition, effect_event, battle_state, content_index)
        return true
    if payload is ApplyEffectPayloadScript:
        _apply_effect_payload(payload, effect_definition, effect_event, battle_state, content_index)
        return true
    if payload is RemoveEffectPayloadScript:
        _remove_effect_payload(payload, effect_definition, effect_event, battle_state)
        return true
    if payload is RuleModPayloadScript:
        _apply_rule_mod_payload(payload, effect_event, battle_state)
        return true
    return false

func _apply_field_payload(payload, effect_definition, effect_event, battle_state, content_index) -> void:
    var before_field = battle_state.field_state
    if before_field != null:
        var before_field_definition = field_service.get_field_definition_for_state(before_field, content_index)
        if before_field_definition != null and not before_field_definition.on_break_effect_ids.is_empty():
            var break_events: Array = field_service.collect_lifecycle_effect_events(
                "field_break",
                before_field,
                before_field_definition.on_break_effect_ids,
                battle_state,
                content_index,
                effect_event.chain_context
            )
            if not break_events.is_empty():
                var break_invalid_code = trigger_batch_runner.execute_trigger_batch(
                    "__field_break__",
                    battle_state,
                    content_index,
                    [],
                    battle_state.chain_context,
                    break_events
                )
                if break_invalid_code != null:
                    last_invalid_battle_code = break_invalid_code
                    return
        battle_state.field_rule_mod_instances.clear()
        battle_state.field_state = null
    var field_state = FieldStateScript.new()
    field_state.field_def_id = payload.field_definition_id
    field_state.instance_id = id_factory.next_id("field")
    field_state.creator = _resolve_field_creator(effect_event)
    field_state.remaining_turns = effect_definition.duration
    field_state.source_instance_id = effect_event.source_instance_id
    field_state.source_kind_order = effect_event.source_kind_order
    field_state.source_order_speed_snapshot = effect_event.source_order_speed_snapshot
    battle_state.field_state = field_state
    var field_change = FieldChangeScript.new()
    field_change.change_kind = "apply"
    field_change.before_field_id = before_field.field_def_id if before_field != null else null
    field_change.after_field_id = field_state.field_def_id
    field_change.before_remaining_turns = before_field.remaining_turns if before_field != null else null
    field_change.after_remaining_turns = field_state.remaining_turns
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_APPLY_FIELD,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "effect_roll": _resolve_effect_roll(effect_event),
            "field_change": field_change,
            "payload_summary": "field -> %s" % field_state.field_def_id,
        }
    ))

func _apply_effect_payload(payload, effect_definition, effect_event, battle_state, content_index) -> void:
    var target_unit = _resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not _is_effect_target_valid(target_unit):
        return
    var target_definition = content_index.effects.get(payload.effect_definition_id)
    if target_definition == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
        return
    var created_instance = effect_instance_service.create_instance(
        target_definition,
        target_unit.unit_instance_id,
        battle_state,
        effect_event.source_instance_id,
        effect_event.source_kind_order,
        effect_event.source_order_speed_snapshot
    )
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_APPLY_EFFECT,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "target_instance_id": target_unit.unit_instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "effect_roll": _resolve_effect_roll(effect_event),
            "payload_summary": "apply effect %s (%s)" % [payload.effect_definition_id, created_instance.instance_id],
        }
    ))

func _remove_effect_payload(payload, effect_definition, effect_event, battle_state) -> void:
    var target_unit = _resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not _is_effect_target_valid(target_unit):
        return
    var removed_instance = effect_instance_service.remove_instance(target_unit.unit_instance_id, payload.effect_definition_id, battle_state)
    if removed_instance == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_REMOVE_AMBIGUOUS
        return
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_REMOVE_EFFECT,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "target_instance_id": target_unit.unit_instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "effect_roll": _resolve_effect_roll(effect_event),
            "payload_summary": "remove effect %s" % payload.effect_definition_id,
        }
    ))

func _apply_rule_mod_payload(payload, effect_event, battle_state) -> void:
    var owner_ref = _resolve_rule_mod_owner(payload, effect_event, battle_state)
    if owner_ref == null:
        return
    var resolved_value = rule_mod_value_resolver.resolve_value(payload, effect_event, battle_state)
    if rule_mod_value_resolver.last_error_code != null:
        last_invalid_battle_code = rule_mod_value_resolver.last_error_code
        return
    var created_instance = rule_mod_service.create_instance(
        payload,
        owner_ref,
        battle_state,
        effect_event.source_instance_id,
        effect_event.source_kind_order,
        effect_event.source_order_speed_snapshot,
        resolved_value
    )
    if created_instance == null:
        last_invalid_battle_code = rule_mod_service.last_error_code if rule_mod_service != null else ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        return
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_RULE_MOD_APPLY,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "target_instance_id": owner_ref["id"],
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "effect_roll": _resolve_effect_roll(effect_event),
            "payload_summary": "rule mod %s (%s)" % [created_instance.mod_kind, created_instance.instance_id],
        }
    ))

func _resolve_field_creator(effect_event) -> String:
    if effect_event != null and effect_event.owner_id != null:
        var owner_id := str(effect_event.owner_id)
        if not owner_id.is_empty():
            return owner_id
    if effect_event != null and effect_event.chain_context != null and effect_event.chain_context.actor_id != null:
        var actor_id := str(effect_event.chain_context.actor_id)
        if not actor_id.is_empty():
            return actor_id
    return ""

func _resolve_rule_mod_owner(payload, effect_event, battle_state):
    match payload.scope:
        "self":
            var owner_unit = battle_state.get_unit(effect_event.owner_id)
            if not _is_effect_target_valid(owner_unit):
                return null
            return {"scope": "unit", "id": owner_unit.unit_instance_id}
        "target":
            if effect_event.chain_context == null or effect_event.chain_context.target_unit_id == null:
                return null
            var target_unit = battle_state.get_unit(str(effect_event.chain_context.target_unit_id))
            if not _is_effect_target_valid(target_unit):
                return null
            return {"scope": "unit", "id": target_unit.unit_instance_id}
        "field":
            return {"scope": "field", "id": "field"}
        _:
            last_invalid_battle_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            return null

func _resolve_target_unit(scope: String, effect_event, battle_state):
    match scope:
        "self":
            return battle_state.get_unit(effect_event.owner_id)
        "target":
            if effect_event.chain_context == null or effect_event.chain_context.target_unit_id == null:
                return null
            return battle_state.get_unit(str(effect_event.chain_context.target_unit_id))
        _:
            return null

func _is_effect_target_valid(target_unit) -> bool:
    return target_unit != null and target_unit.leave_state == LeaveStatesScript.ACTIVE and target_unit.current_hp > 0

func _resolve_effect_roll(effect_event) -> Variant:
    if effect_event == null:
        return null
    return effect_event.sort_random_roll
