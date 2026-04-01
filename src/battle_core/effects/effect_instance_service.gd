extends RefCounted
class_name EffectInstanceService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const EffectInstanceScript := preload("res://src/battle_core/runtime/effect_instance.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var id_factory
var last_invalid_battle_code: Variant = null
var last_apply_skipped: bool = false

func create_instance(effect_definition, owner_id: String, battle_state, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int, meta: Dictionary = {}):
    last_invalid_battle_code = null
    last_apply_skipped = false
    var owner_unit = battle_state.get_unit(owner_id)
    if owner_unit == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return null
    var existing_instance = _find_existing(owner_unit, effect_definition.id)
    match effect_definition.stacking:
        ContentSchemaScript.STACKING_NONE:
            if existing_instance != null:
                last_apply_skipped = true
                return existing_instance
        ContentSchemaScript.STACKING_REFRESH:
            if existing_instance != null:
                existing_instance.remaining = effect_definition.duration
                existing_instance.meta = meta.duplicate(true)
                return existing_instance
        ContentSchemaScript.STACKING_REPLACE:
            if existing_instance != null:
                owner_unit.effect_instances.erase(existing_instance)
        ContentSchemaScript.STACKING_STACK:
            var matching_instances: Array = _find_matching_instances(owner_unit, effect_definition.id)
            var max_stacks: int = int(effect_definition.max_stacks)
            if max_stacks > 0 and matching_instances.size() >= max_stacks:
                last_apply_skipped = true
                return matching_instances[0]
    var effect_instance = EffectInstanceScript.new()
    effect_instance.instance_id = id_factory.next_id("effect")
    effect_instance.def_id = effect_definition.id
    effect_instance.owner = owner_id
    effect_instance.remaining = effect_definition.duration
    effect_instance.created_turn = battle_state.turn_index
    effect_instance.source_instance_id = source_instance_id
    effect_instance.source_kind_order = source_kind_order
    effect_instance.source_order_speed_snapshot = source_order_speed_snapshot
    effect_instance.persists_on_switch = effect_definition.persists_on_switch
    effect_instance.meta = meta.duplicate(true)
    owner_unit.effect_instances.append(effect_instance)
    return effect_instance

func remove_instance(owner_id: String, effect_definition_id: String, battle_state):
    var owner_unit = battle_state.get_unit(owner_id)
    if owner_unit == null:
        return null
    var matching_instances: Array = _find_matching_instances(owner_unit, effect_definition_id)
    if matching_instances.size() != 1:
        return null
    var existing_instance = matching_instances[0]
    owner_unit.effect_instances.erase(existing_instance)
    return existing_instance

func _find_existing(owner_unit, effect_definition_id: String):
    for effect_instance in owner_unit.effect_instances:
        if effect_instance.def_id == effect_definition_id:
            return effect_instance
    return null

func _find_matching_instances(owner_unit, effect_definition_id: String) -> Array:
    var matching_instances: Array = []
    for effect_instance in owner_unit.effect_instances:
        if effect_instance.def_id == effect_definition_id:
            matching_instances.append(effect_instance)
    return matching_instances
