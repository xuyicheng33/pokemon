extends RefCounted
class_name RuleModService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "id_factory",
		"source": "id_factory",
		"nested": true,
	},
]

const RuleModReadServiceScript := preload("res://src/battle_core/effects/rule_mod_read_service.gd")
const RuleModWriteServiceScript := preload("res://src/battle_core/effects/rule_mod_write_service.gd")

var id_factory
var last_error_code: Variant = null
var last_apply_skipped: bool = false
var _read_service = RuleModReadServiceScript.new()
var _write_service = RuleModWriteServiceScript.new()

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func error_state() -> Dictionary:
    var read_error_state: Dictionary = _read_service.error_state()
    var write_error_state: Dictionary = _write_service.error_state()
    return {
        "code": last_error_code,
        "message": String(read_error_state.get("message", write_error_state.get("message", ""))),
    }

func create_instance(rule_mod_payload, owner_ref: Dictionary, battle_state, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int, resolved_value = null, source_stacking_token: String = "") -> Variant:
    _write_service.id_factory = id_factory
    last_apply_skipped = false
    var created_instance = _write_service.create_instance(
        rule_mod_payload,
        owner_ref,
        battle_state,
        source_instance_id,
        source_kind_order,
        source_order_speed_snapshot,
        resolved_value,
        source_stacking_token
    )
    var write_error_state: Dictionary = _write_service.error_state()
    last_error_code = write_error_state.get("code", null)
    last_apply_skipped = _write_service.last_apply_skipped
    return created_instance

func get_final_multiplier(battle_state, owner_id: String) -> float:
    return _read_service.get_final_multiplier(battle_state, owner_id)

func resolve_mp_regen_value(battle_state, owner_id: String, base_regen: int) -> int:
    return _read_service.resolve_mp_regen_value(battle_state, owner_id, base_regen)

func is_action_allowed(battle_state, owner_id: String, action_type: String, skill_id: String = "") -> bool:
    var is_allowed := _read_service.is_action_allowed(battle_state, owner_id, action_type, skill_id)
    var read_error_state: Dictionary = _read_service.error_state()
    last_error_code = read_error_state.get("code", null)
    return is_allowed

func resolve_incoming_accuracy(battle_state, owner_id: String, base_accuracy: int) -> int:
    return _read_service.resolve_incoming_accuracy(battle_state, owner_id, base_accuracy)

func has_nullify_field_accuracy(battle_state, owner_id: String) -> bool:
    return _read_service.has_nullify_field_accuracy(battle_state, owner_id)

func resolve_incoming_heal_final_multiplier(battle_state, owner_id: String) -> float:
    return _read_service.resolve_incoming_heal_final_multiplier(battle_state, owner_id)

func resolve_incoming_action_final_multiplier(battle_state, owner_id: String, command_type: String, combat_type_id: String) -> float:
    return _read_service.resolve_incoming_action_final_multiplier(battle_state, owner_id, command_type, combat_type_id)

func decrement_for_trigger(battle_state, trigger_name: String) -> Array:
    return _write_service.decrement_for_trigger(battle_state, trigger_name)
