extends RefCounted
class_name RuleModService

const RuleModReadServiceScript := preload("res://src/battle_core/effects/rule_mod_read_service.gd")
const RuleModWriteServiceScript := preload("res://src/battle_core/effects/rule_mod_write_service.gd")

var id_factory
var last_error_code: Variant = null
var _read_service = RuleModReadServiceScript.new()
var _write_service = RuleModWriteServiceScript.new()

func create_instance(rule_mod_payload, owner_ref: Dictionary, battle_state, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int, resolved_value = null):
    _write_service.id_factory = id_factory
    var created_instance = _write_service.create_instance(
        rule_mod_payload,
        owner_ref,
        battle_state,
        source_instance_id,
        source_kind_order,
        source_order_speed_snapshot,
        resolved_value
    )
    last_error_code = _write_service.last_error_code
    return created_instance

func get_final_multiplier(battle_state, owner_id: String) -> float:
    return _read_service.get_final_multiplier(battle_state, owner_id)

func resolve_mp_regen_value(battle_state, owner_id: String, base_regen: int) -> int:
    return _read_service.resolve_mp_regen_value(battle_state, owner_id, base_regen)

func is_skill_allowed(battle_state, owner_id: String, skill_id: String) -> bool:
    return _read_service.is_skill_allowed(battle_state, owner_id, skill_id)

func is_action_allowed(battle_state, owner_id: String, action_type: String, skill_id: String = "") -> bool:
    return _read_service.is_action_allowed(battle_state, owner_id, action_type, skill_id)

func resolve_incoming_accuracy(battle_state, owner_id: String, base_accuracy: int) -> int:
    return _read_service.resolve_incoming_accuracy(battle_state, owner_id, base_accuracy)

func decrement_for_trigger(battle_state, trigger_name: String) -> Array:
    return _write_service.decrement_for_trigger(battle_state, trigger_name)
