extends RefCounted
class_name PayloadRemoveEffectHandler

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "battle_logger",
		"source": "battle_logger",
		"nested": true,
	},
	{
		"field": "log_event_builder",
		"source": "log_event_builder",
		"nested": true,
	},
	{
		"field": "effect_instance_service",
		"source": "effect_instance_service",
		"nested": true,
	},
	{
		"field": "target_helper",
		"source": "payload_unit_target_helper",
		"nested": true,
	},
	{
		"field": "effect_event_helper",
		"source": "payload_effect_event_helper",
		"nested": true,
	},
]

const EventTypesScript := preload("res://src/shared/event_types.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var effect_instance_service: EffectInstanceService
var target_helper: PayloadUnitTargetHelper
var effect_event_helper: PayloadEffectEventHelper

var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func execute(payload, effect_definition, effect_event: EffectEvent, battle_state: BattleState, _content_index: BattleContentIndex, _execute_trigger_batch: Callable = Callable()) -> void:
	last_invalid_battle_code = null
	if not payload is RemoveEffectPayloadScript:
		return
	var target_unit = target_helper.resolve_target_unit(effect_definition.scope, effect_event, battle_state)
	if not target_helper.is_effect_target_valid(target_unit, effect_definition.scope, effect_event):
		return
	if String(payload.remove_mode) == "all":
		var removed_instances: Array = effect_instance_service.remove_all_instances(target_unit.unit_instance_id, payload.effect_definition_id, battle_state)
		if removed_instances.is_empty():
			return
		battle_logger.append_event(log_event_builder.build_effect_event(
			EventTypesScript.EFFECT_REMOVE_EFFECT,
			battle_state,
			String(effect_event.event_id),
			{
				"source_instance_id": effect_event.source_instance_id,
				"target_instance_id": target_unit.unit_instance_id,
				"priority": effect_event.priority,
				"trigger_name": effect_event.trigger_name,
				"effect_roll": effect_event_helper.resolve_effect_roll(effect_event),
				"payload_summary": "remove all effect %s x%d" % [payload.effect_definition_id, removed_instances.size()],
			}
		))
		return
	var removed_instance = effect_instance_service.remove_instance(target_unit.unit_instance_id, payload.effect_definition_id, battle_state)
	if removed_instance == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_REMOVE_AMBIGUOUS
		return
	battle_logger.append_event(log_event_builder.build_effect_event(
		EventTypesScript.EFFECT_REMOVE_EFFECT,
		battle_state,
		String(effect_event.event_id),
		{
			"source_instance_id": effect_event.source_instance_id,
			"target_instance_id": target_unit.unit_instance_id,
			"priority": effect_event.priority,
			"trigger_name": effect_event.trigger_name,
			"effect_roll": effect_event_helper.resolve_effect_roll(effect_event),
			"payload_summary": "remove effect %s" % payload.effect_definition_id,
		}
	))
