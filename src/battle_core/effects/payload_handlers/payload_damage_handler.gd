extends RefCounted
class_name PayloadDamageHandler

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "payload_damage_runtime_service",
		"source": "payload_damage_runtime_service",
		"nested": true,
	},
]

const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")

var last_invalid_battle_code: Variant = null
var payload_damage_runtime_service: PayloadDamageRuntimeService

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func execute(payload, effect_definition, effect_event, battle_state, content_index, _execute_trigger_batch: Callable = Callable()) -> void:
	last_invalid_battle_code = null
	if not payload is DamagePayloadScript:
		return
	payload_damage_runtime_service.apply_damage_payload(payload, effect_definition, effect_event, battle_state, content_index)
	if payload_damage_runtime_service != null and payload_damage_runtime_service.has_method("invalid_battle_code"):
		last_invalid_battle_code = payload_damage_runtime_service.invalid_battle_code()
