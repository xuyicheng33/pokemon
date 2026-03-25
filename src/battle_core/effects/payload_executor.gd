extends RefCounted
class_name PayloadExecutor

const EventTypesScript := preload("res://src/shared/event_types.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const FieldChangeScript := preload("res://src/battle_core/contracts/field_change.gd")
const ValueChangeScript := preload("res://src/battle_core/contracts/value_change.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_logger
var log_event_builder
var id_factory
var effect_instance_service
var rule_mod_service
var damage_service
var stat_calculator
var faint_resolver
var last_invalid_battle_code: Variant = null

func execute_effect_event(effect_event, battle_state, content_index) -> void:
    last_invalid_battle_code = null
    if not _enter_effect_guard(effect_event, battle_state):
        return
    var effect_definition = content_index.effects.get(effect_event.effect_definition_id)
    if effect_definition == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
        _leave_effect_guard(battle_state)
        return
    for payload in effect_definition.payloads:
        execute_payload(payload, effect_definition, effect_event, battle_state, content_index)
        if last_invalid_battle_code != null:
            _leave_effect_guard(battle_state)
            return
    _leave_effect_guard(battle_state)

func execute_payload(payload, effect_definition, effect_event, battle_state, content_index) -> void:
    if payload is DamagePayloadScript:
        _apply_damage_payload(payload, effect_definition, effect_event, battle_state, content_index)
        return
    if payload is HealPayloadScript:
        _apply_heal_payload(payload, effect_definition, effect_event, battle_state)
        return
    if payload is ResourceModPayloadScript:
        _apply_resource_mod_payload(payload, effect_definition, effect_event, battle_state)
        return
    if payload is StatModPayloadScript:
        _apply_stat_mod_payload(payload, effect_definition, effect_event, battle_state)
        return
    if payload is ApplyFieldPayloadScript:
        _apply_field_payload(payload, effect_definition, effect_event, battle_state)
        return
    if payload is ApplyEffectPayloadScript:
        _apply_effect_payload(payload, effect_definition, effect_event, battle_state, content_index)
        return
    if payload is RemoveEffectPayloadScript:
        _remove_effect_payload(payload, effect_definition, effect_event, battle_state)
        return
    if payload is RuleModPayloadScript:
        _apply_rule_mod_payload(payload, effect_definition, effect_event, battle_state)
        return
    last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION

func _apply_damage_payload(payload, effect_definition, effect_event, battle_state, _content_index) -> void:
    var target_unit = _resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not _is_effect_target_valid(target_unit):
        return
    var amount: int = payload.amount
    if payload.use_formula:
        var actor_unit = battle_state.get_unit(effect_event.owner_id)
        if actor_unit == null:
            return
        var attack_value: int = actor_unit.base_attack
        var defense_value: int = target_unit.base_defense
        amount = damage_service.apply_final_mod(
            damage_service.calc_base_damage(battle_state.battle_level, max(1, amount), attack_value, defense_value),
            rule_mod_service.get_final_multiplier(battle_state, effect_event.owner_id)
        )
    _apply_hp_change(
        battle_state,
        effect_event,
        target_unit,
        -max(1, amount),
        EventTypesScript.EFFECT_DAMAGE,
        payload.payload_type if not payload.payload_type.is_empty() else "damage"
    )

func _apply_heal_payload(payload, effect_definition, effect_event, battle_state) -> void:
    var target_unit = _resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not _is_effect_target_valid(target_unit):
        return
    _apply_hp_change(battle_state, effect_event, target_unit, payload.amount, EventTypesScript.EFFECT_HEAL, "heal")

func _apply_resource_mod_payload(payload, effect_definition, effect_event, battle_state) -> void:
    var target_unit = _resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not _is_effect_target_valid(target_unit):
        return
    var before_value: int = target_unit.current_mp
    target_unit.current_mp = clamp(target_unit.current_mp + payload.amount, 0, target_unit.max_mp)
    if before_value == target_unit.current_mp:
        return
    var value_change = _build_value_change(target_unit.unit_instance_id, payload.resource_key, before_value, target_unit.current_mp)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_RESOURCE_MOD,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "target_instance_id": target_unit.unit_instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "value_changes": [value_change],
            "payload_summary": "%s mp %+d" % [target_unit.public_id, value_change.delta],
        }
    ))

func _apply_stat_mod_payload(payload, effect_definition, effect_event, battle_state) -> void:
    var target_unit = _resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not _is_effect_target_valid(target_unit):
        return
    var before_value: int = int(target_unit.stat_stages.get(payload.stat_name, 0))
    var after_value: int = clamp(before_value + payload.stage_delta, -2, 2)
    if before_value == after_value:
        return
    target_unit.stat_stages[payload.stat_name] = after_value
    var value_change = _build_value_change(target_unit.unit_instance_id, payload.stat_name, before_value, after_value)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_STAT_MOD,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "target_instance_id": target_unit.unit_instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "value_changes": [value_change],
            "payload_summary": "%s %s %+d" % [target_unit.public_id, payload.stat_name, value_change.delta],
        }
    ))

func _apply_field_payload(payload, effect_definition, effect_event, battle_state) -> void:
    var before_field = battle_state.field_state
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
            "field_change": field_change,
            "payload_summary": "field -> %s" % field_state.field_def_id,
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
            "payload_summary": "remove effect %s" % payload.effect_definition_id,
        }
    ))

func _apply_rule_mod_payload(payload, effect_definition, effect_event, battle_state) -> void:
    var owner_ref = _resolve_rule_mod_owner(payload, effect_event, battle_state)
    if owner_ref == null:
        return
    var created_instance = rule_mod_service.create_instance(
        payload,
        owner_ref,
        battle_state,
        effect_event.source_instance_id,
        effect_event.source_kind_order,
        effect_event.source_order_speed_snapshot
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
            "payload_summary": "rule mod %s (%s)" % [created_instance.mod_kind, created_instance.instance_id],
        }
    ))

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

func _apply_hp_change(battle_state, effect_event, target_unit, delta: int, event_type: String, summary_tag: String) -> void:
    var before_value: int = target_unit.current_hp
    target_unit.current_hp = clamp(target_unit.current_hp + delta, 0, target_unit.max_hp)
    if before_value == target_unit.current_hp:
        return
    var value_change = _build_value_change(target_unit.unit_instance_id, "hp", before_value, target_unit.current_hp)
    var log_event = log_event_builder.build_event(
        event_type,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "target_instance_id": target_unit.unit_instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "value_changes": [value_change],
            "payload_summary": "%s %s %+d" % [target_unit.public_id, summary_tag, value_change.delta],
        }
    )
    battle_logger.append_event(log_event)
    if event_type == EventTypesScript.EFFECT_DAMAGE and faint_resolver != null:
        faint_resolver.record_fatal_damage(
            battle_state,
            target_unit.unit_instance_id,
            before_value,
            target_unit.current_hp,
            effect_event.owner_id,
            effect_event.source_instance_id,
            effect_event.source_kind_order,
            effect_event.source_order_speed_snapshot,
            effect_event.priority,
            log_event.event_step_id
        )

func _build_value_change(entity_id: String, resource_name: String, before_value: int, after_value: int):
    var value_change = ValueChangeScript.new()
    value_change.entity_id = entity_id
    value_change.resource_name = resource_name
    value_change.before_value = before_value
    value_change.after_value = after_value
    value_change.delta = after_value - before_value
    return value_change

func _enter_effect_guard(effect_event, battle_state) -> bool:
    if battle_state.chain_context == null or battle_state.max_chain_depth <= 0:
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return false
    var dedupe_key := "%s|%s|%s" % [effect_event.source_instance_id, effect_event.trigger_name, effect_event.event_id]
    if battle_state.chain_context.effect_dedupe_keys.has(dedupe_key):
        last_invalid_battle_code = ErrorCodesScript.INVALID_CHAIN_DEPTH
        return false
    battle_state.chain_context.effect_dedupe_keys[dedupe_key] = true
    battle_state.chain_context.chain_depth += 1
    if battle_state.chain_context.chain_depth > battle_state.max_chain_depth:
        battle_state.chain_context.chain_depth -= 1
        battle_state.chain_context.effect_dedupe_keys.erase(dedupe_key)
        last_invalid_battle_code = ErrorCodesScript.INVALID_CHAIN_DEPTH
        return false
    return true

func _leave_effect_guard(battle_state) -> void:
    if battle_state.chain_context == null:
        return
    if battle_state.chain_context.chain_depth > 0:
        battle_state.chain_context.chain_depth -= 1
