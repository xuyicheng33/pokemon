extends RefCounted
class_name PayloadHealHandler

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "payload_resource_runtime_service",
		"source": "payload_resource_runtime_service",
		"nested": true,
	},
]

const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")

var last_invalid_battle_code: Variant = null
var payload_resource_runtime_service: PayloadResourceRuntimeService

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)


func execute(payload, effect_definition, effect_event: EffectEvent, battle_state: BattleState, _content_index: BattleContentIndex, _execute_trigger_batch: Callable = Callable()) -> void:
	last_invalid_battle_code = null
	if not payload is HealPayloadScript:
		return
	payload_resource_runtime_service.apply_heal_payload(payload, effect_definition, effect_event, battle_state)
	if payload_resource_runtime_service != null and payload_resource_runtime_service.has_method("invalid_battle_code"):
		last_invalid_battle_code = payload_resource_runtime_service.invalid_battle_code()
