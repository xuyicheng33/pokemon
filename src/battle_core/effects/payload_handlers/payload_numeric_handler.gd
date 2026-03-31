extends RefCounted
class_name PayloadNumericHandler

const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
var battle_logger
var log_event_builder
var damage_service
var combat_type_service
var stat_calculator
var rule_mod_service
var faint_resolver

var last_invalid_battle_code: Variant = null

var payload_unit_target_helper
var payload_damage_runtime_service
var payload_resource_runtime_service
var payload_stat_mod_runtime_service

func resolve_missing_dependency() -> String:
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if damage_service == null:
        return "damage_service"
    if combat_type_service == null:
        return "combat_type_service"
    if stat_calculator == null:
        return "stat_calculator"
    if rule_mod_service == null:
        return "rule_mod_service"
    if faint_resolver == null:
        return "faint_resolver"
    if payload_unit_target_helper == null:
        return "payload_unit_target_helper"
    if payload_damage_runtime_service == null:
        return "payload_damage_runtime_service"
    var damage_missing := str(payload_damage_runtime_service.resolve_missing_dependency())
    if not damage_missing.is_empty():
        return "payload_damage_runtime_service.%s" % damage_missing
    if payload_resource_runtime_service == null:
        return "payload_resource_runtime_service"
    var resource_missing := str(payload_resource_runtime_service.resolve_missing_dependency())
    if not resource_missing.is_empty():
        return "payload_resource_runtime_service.%s" % resource_missing
    if payload_stat_mod_runtime_service == null:
        return "payload_stat_mod_runtime_service"
    var stat_missing := str(payload_stat_mod_runtime_service.resolve_missing_dependency())
    if not stat_missing.is_empty():
        return "payload_stat_mod_runtime_service.%s" % stat_missing
    return ""

func execute(payload, effect_definition, effect_event, battle_state, content_index) -> bool:
    last_invalid_battle_code = null
    if payload is DamagePayloadScript:
        payload_damage_runtime_service.apply_damage_payload(payload, effect_definition, effect_event, battle_state, content_index)
        return true
    if payload is HealPayloadScript:
        payload_resource_runtime_service.apply_heal_payload(payload, effect_definition, effect_event, battle_state)
        return true
    if payload is ResourceModPayloadScript:
        payload_resource_runtime_service.apply_resource_mod_payload(payload, effect_definition, effect_event, battle_state)
        return true
    if payload is StatModPayloadScript:
        payload_stat_mod_runtime_service.apply_stat_mod_payload(payload, effect_definition, effect_event, battle_state)
        return true
    return false
