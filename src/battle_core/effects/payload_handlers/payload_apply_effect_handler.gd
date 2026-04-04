extends RefCounted
class_name PayloadApplyEffectHandler

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
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

func execute(payload, effect_definition, effect_event, battle_state, content_index, _execute_trigger_batch: Callable = Callable()) -> void:
	last_invalid_battle_code = null
	if not payload is ApplyEffectPayloadScript:
		return
	var target_unit = target_helper.resolve_target_unit(effect_definition.scope, effect_event, battle_state)
	if not target_helper.is_effect_target_valid(target_unit, effect_definition.scope, effect_event):
		return
	var target_definition = content_index.effects.get(payload.effect_definition_id)
	if target_definition == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
		return
	var created_instance = effect_instance_service.create_instance(
		target_definition,
		target_unit.unit_instance_id,
		battle_state,
		effect_event.source_instance_id,
		effect_event.source_kind_order,
		effect_event.source_order_speed_snapshot,
		{
			"source_owner_id": String(effect_event.owner_id),
		}
	)
	var effect_invalid_code = effect_instance_service.invalid_battle_code()
	if effect_invalid_code != null:
		last_invalid_battle_code = effect_invalid_code
		return
	if effect_instance_service.last_apply_skipped:
		return
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.EFFECT_APPLY_EFFECT,
		battle_state,
		{
			"source_instance_id": effect_event.source_instance_id,
			"target_instance_id": target_unit.unit_instance_id,
			"priority": effect_event.priority,
			"trigger_name": effect_event.trigger_name,
			"cause_event_id": effect_event.event_id,
			"effect_roll": effect_event_helper.resolve_effect_roll(effect_event),
			"payload_summary": "apply effect %s (%s)" % [payload.effect_definition_id, created_instance.instance_id],
		}
	))
