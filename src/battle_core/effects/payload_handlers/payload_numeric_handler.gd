extends RefCounted
class_name PayloadNumericHandler

const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const PayloadUnitTargetHelperScript := preload("res://src/battle_core/effects/payload_handlers/payload_unit_target_helper.gd")
const PayloadDamageRuntimeServiceScript := preload("res://src/battle_core/effects/payload_handlers/payload_damage_runtime_service.gd")
const PayloadResourceRuntimeServiceScript := preload("res://src/battle_core/effects/payload_handlers/payload_resource_runtime_service.gd")
const PayloadStatModRuntimeServiceScript := preload("res://src/battle_core/effects/payload_handlers/payload_stat_mod_runtime_service.gd")

var battle_logger
var log_event_builder
var damage_service
var combat_type_service
var stat_calculator
var rule_mod_service
var faint_resolver

var last_invalid_battle_code: Variant = null

var _target_helper = PayloadUnitTargetHelperScript.new()
var _damage_runtime_service = PayloadDamageRuntimeServiceScript.new()
var _resource_runtime_service = PayloadResourceRuntimeServiceScript.new()
var _stat_mod_runtime_service = PayloadStatModRuntimeServiceScript.new()

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
    _sync_runtime_services()
    var damage_missing := _damage_runtime_service.resolve_missing_dependency()
    if not damage_missing.is_empty():
        return "damage_runtime_service.%s" % damage_missing
    var resource_missing := _resource_runtime_service.resolve_missing_dependency()
    if not resource_missing.is_empty():
        return "resource_runtime_service.%s" % resource_missing
    var stat_missing := _stat_mod_runtime_service.resolve_missing_dependency()
    if not stat_missing.is_empty():
        return "stat_mod_runtime_service.%s" % stat_missing
    return ""

func execute(payload, effect_definition, effect_event, battle_state, content_index) -> bool:
    last_invalid_battle_code = null
    _sync_runtime_services()
    if payload is DamagePayloadScript:
        _damage_runtime_service.apply_damage_payload(payload, effect_definition, effect_event, battle_state, content_index)
        return true
    if payload is HealPayloadScript:
        _resource_runtime_service.apply_heal_payload(payload, effect_definition, effect_event, battle_state)
        return true
    if payload is ResourceModPayloadScript:
        _resource_runtime_service.apply_resource_mod_payload(payload, effect_definition, effect_event, battle_state)
        return true
    if payload is StatModPayloadScript:
        _stat_mod_runtime_service.apply_stat_mod_payload(payload, effect_definition, effect_event, battle_state)
        return true
    return false

func _sync_runtime_services() -> void:
    _damage_runtime_service.battle_logger = battle_logger
    _damage_runtime_service.log_event_builder = log_event_builder
    _damage_runtime_service.damage_service = damage_service
    _damage_runtime_service.combat_type_service = combat_type_service
    _damage_runtime_service.stat_calculator = stat_calculator
    _damage_runtime_service.rule_mod_service = rule_mod_service
    _damage_runtime_service.faint_resolver = faint_resolver
    _damage_runtime_service.target_helper = _target_helper

    _resource_runtime_service.battle_logger = battle_logger
    _resource_runtime_service.log_event_builder = log_event_builder
    _resource_runtime_service.target_helper = _target_helper

    _stat_mod_runtime_service.battle_logger = battle_logger
    _stat_mod_runtime_service.log_event_builder = log_event_builder
    _stat_mod_runtime_service.target_helper = _target_helper
