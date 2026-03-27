extends RefCounted
class_name PayloadNumericHandler

const EventTypesScript := preload("res://src/shared/event_types.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ValueChangeScript := preload("res://src/battle_core/contracts/value_change.gd")

var battle_logger
var log_event_builder
var damage_service
var rule_mod_service
var faint_resolver

var last_invalid_battle_code: Variant = null

func resolve_missing_dependency() -> String:
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if damage_service == null:
        return "damage_service"
    if rule_mod_service == null:
        return "rule_mod_service"
    return ""

func execute(payload, effect_definition, effect_event, battle_state) -> bool:
    last_invalid_battle_code = null
    if payload is DamagePayloadScript:
        _apply_damage_payload(payload, effect_definition, effect_event, battle_state)
        return true
    if payload is HealPayloadScript:
        _apply_heal_payload(payload, effect_definition, effect_event, battle_state)
        return true
    if payload is ResourceModPayloadScript:
        _apply_resource_mod_payload(payload, effect_definition, effect_event, battle_state)
        return true
    if payload is StatModPayloadScript:
        _apply_stat_mod_payload(payload, effect_definition, effect_event, battle_state)
        return true
    return false

func _apply_damage_payload(payload, effect_definition, effect_event, battle_state) -> void:
    var target_unit = _resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not _is_effect_target_valid(target_unit):
        return
    var amount: int = payload.amount
    if payload.use_formula:
        var actor_unit = battle_state.get_unit(effect_event.owner_id)
        if actor_unit == null:
            return
        amount = damage_service.apply_final_mod(
            damage_service.calc_base_damage(
                battle_state.battle_level,
                max(1, amount),
                actor_unit.base_attack,
                target_unit.base_defense
            ),
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
            "effect_roll": _resolve_effect_roll(effect_event),
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
            "effect_roll": _resolve_effect_roll(effect_event),
            "value_changes": [value_change],
            "payload_summary": "%s %s %+d" % [target_unit.public_id, payload.stat_name, value_change.delta],
        }
    ))

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
            "effect_roll": _resolve_effect_roll(effect_event),
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

func _resolve_effect_roll(effect_event) -> Variant:
    if effect_event == null:
        return null
    return effect_event.sort_random_roll
