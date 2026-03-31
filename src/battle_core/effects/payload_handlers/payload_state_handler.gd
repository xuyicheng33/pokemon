extends RefCounted
class_name PayloadStateHandler

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const PayloadUnitTargetHelperScript := preload("res://src/battle_core/effects/payload_handlers/payload_unit_target_helper.gd")

var battle_logger
var log_event_builder
var id_factory
var effect_instance_service
var rule_mod_service
var rule_mod_value_resolver
var field_service
var field_apply_service

var last_invalid_battle_code: Variant = null
var _target_helper = PayloadUnitTargetHelperScript.new()

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
    if field_service.has_method("resolve_missing_dependency"):
        var field_missing := str(field_service.resolve_missing_dependency())
        if not field_missing.is_empty():
            return "field_service.%s" % field_missing
    if field_apply_service == null:
        return "field_apply_service"
    if field_apply_service.has_method("resolve_missing_dependency"):
        var field_apply_missing := str(field_apply_service.resolve_missing_dependency())
        if not field_apply_missing.is_empty():
            return "field_apply_service.%s" % field_apply_missing
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
    var invalid_code = field_apply_service.apply_field(effect_definition, payload, effect_event, battle_state, content_index)
    if invalid_code != null:
        last_invalid_battle_code = invalid_code
        return

func _apply_effect_payload(payload, effect_definition, effect_event, battle_state, content_index) -> void:
    var target_unit = _target_helper.resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not _target_helper.is_effect_target_valid(target_unit, effect_definition.scope, effect_event):
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
    if effect_instance_service.last_invalid_battle_code != null:
        last_invalid_battle_code = effect_instance_service.last_invalid_battle_code
        return
    if effect_instance_service.last_apply_skipped:
        return
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
    var target_unit = _target_helper.resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not _target_helper.is_effect_target_valid(target_unit, effect_definition.scope, effect_event):
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

func _resolve_rule_mod_owner(payload, effect_event, battle_state):
    match payload.scope:
        "self":
            var owner_unit = battle_state.get_unit(effect_event.owner_id)
            if not _target_helper.is_effect_target_valid(owner_unit, payload.scope, effect_event):
                return null
            return {"scope": "unit", "id": owner_unit.unit_instance_id}
        "target":
            if effect_event.chain_context == null or effect_event.chain_context.target_unit_id == null:
                return null
            var target_unit = battle_state.get_unit(str(effect_event.chain_context.target_unit_id))
            if not _target_helper.is_effect_target_valid(target_unit, payload.scope, effect_event):
                return null
            return {"scope": "unit", "id": target_unit.unit_instance_id}
        "field":
            return {"scope": "field", "id": "field"}
        _:
            last_invalid_battle_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            return null

func _resolve_effect_roll(effect_event) -> Variant:
    if effect_event == null:
        return null
    return effect_event.sort_random_roll
