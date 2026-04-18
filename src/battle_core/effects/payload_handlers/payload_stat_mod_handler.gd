extends RefCounted
class_name PayloadStatModHandler

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "payload_stat_mod_runtime_service",
		"source": "payload_stat_mod_runtime_service",
		"nested": true,
	},
]

const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var last_invalid_battle_code: Variant = null
var payload_stat_mod_runtime_service

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func execute(payload, effect_definition, effect_event, battle_state, _content_index, _execute_trigger_batch: Callable = Callable()) -> void:
	last_invalid_battle_code = null
	if not payload is StatModPayloadScript:
		return
	payload_stat_mod_runtime_service.apply_stat_mod_payload(payload, effect_definition, effect_event, battle_state)
