extends RefCounted
class_name PayloadRemoveEffectHandler

const EventTypesScript := preload("res://src/shared/event_types.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_logger
var log_event_builder
var effect_instance_service
var target_helper
var effect_event_helper

var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	if battle_logger == null:
		return "battle_logger"
	if log_event_builder == null:
		return "log_event_builder"
	if effect_instance_service == null:
		return "effect_instance_service"
	if target_helper == null:
		return "target_helper"
	if effect_event_helper == null:
		return "effect_event_helper"
	return ""

func execute(payload, effect_definition, effect_event, battle_state, _content_index, _execute_trigger_batch: Callable = Callable()) -> void:
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
		battle_logger.append_event(log_event_builder.build_event(
			EventTypesScript.EFFECT_REMOVE_EFFECT,
			battle_state,
			{
				"source_instance_id": effect_event.source_instance_id,
				"target_instance_id": target_unit.unit_instance_id,
				"priority": effect_event.priority,
				"trigger_name": effect_event.trigger_name,
				"cause_event_id": effect_event.event_id,
				"effect_roll": effect_event_helper.resolve_effect_roll(effect_event),
				"payload_summary": "remove all effect %s x%d" % [payload.effect_definition_id, removed_instances.size()],
			}
		))
		return
	var removed_instance = effect_instance_service.remove_instance(target_unit.unit_instance_id, payload.effect_definition_id, battle_state)
	if removed_instance == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_REMOVE_AMBIGUOUS
		return
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.EFFECT_REMOVE_EFFECT,
		battle_state,
		{
			"source_instance_id": effect_event.source_instance_id,
			"target_instance_id": target_unit.unit_instance_id,
			"priority": effect_event.priority,
			"trigger_name": effect_event.trigger_name,
			"cause_event_id": effect_event.event_id,
			"effect_roll": effect_event_helper.resolve_effect_roll(effect_event),
			"payload_summary": "remove effect %s" % payload.effect_definition_id,
		}
	))
