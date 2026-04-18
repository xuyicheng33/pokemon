extends RefCounted
class_name PayloadApplyFieldHandler

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "field_apply_service",
		"source": "field_apply_service",
		"nested": true,
	},
]

const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")

var last_invalid_battle_code: Variant = null
var field_apply_service

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func execute(payload, effect_definition, effect_event, battle_state, content_index, execute_trigger_batch: Callable = Callable()) -> void:
	last_invalid_battle_code = null
	if not payload is ApplyFieldPayloadScript:
		return
	var invalid_code = field_apply_service.apply_field(
		effect_definition,
		payload,
		effect_event,
		battle_state,
		content_index,
		execute_trigger_batch
	)
	if invalid_code != null:
		last_invalid_battle_code = invalid_code
