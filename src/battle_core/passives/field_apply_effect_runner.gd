extends RefCounted
class_name FieldApplyEffectRunner

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")

var field_service
var trigger_dispatcher
var trigger_batch_runner
var id_factory
var context_resolver

func resolve_missing_dependency() -> String:
	if field_service == null:
		return "field_service"
	if trigger_dispatcher == null:
		return "trigger_dispatcher"
	if trigger_batch_runner == null:
		return "trigger_batch_runner"
	if id_factory == null:
		return "id_factory"
	if context_resolver == null:
		return "context_resolver"
	return ""

func create_field_state(effect_definition, payload, effect_event):
	var field_state = FieldStateScript.new()
	field_state.field_def_id = payload.field_definition_id
	field_state.instance_id = id_factory.next_id("field")
	field_state.creator = context_resolver.resolve_field_creator(effect_event)
	assert(not field_state.creator.is_empty(), "FieldApplyEffectRunner.create_field_state requires non-empty creator for %s" % field_state.field_def_id)
	field_state.remaining_turns = effect_definition.duration
	field_state.source_instance_id = effect_event.source_instance_id
	field_state.source_kind_order = effect_event.source_kind_order
	field_state.source_order_speed_snapshot = effect_event.source_order_speed_snapshot
	return field_state

func execute_field_effects(trigger_name: String, field_state, battle_state, content_index, chain_context) -> Variant:
	var field_definition = field_service.get_field_definition_for_state(field_state, content_index)
	if field_definition == null or field_definition.effect_ids.is_empty():
		return null
	var effect_events: Array = field_service.collect_lifecycle_effect_events(
		trigger_name,
		field_state,
		field_definition.effect_ids,
		battle_state,
		content_index,
		chain_context
	)
	if effect_events.is_empty():
		return null
	return trigger_batch_runner.execute_trigger_batch(
		"__field_%s__" % trigger_name,
		battle_state,
		content_index,
		[],
		battle_state.chain_context,
		effect_events
	)

func execute_success_effects(effect_ids: PackedStringArray, effect_event, battle_state, content_index) -> Variant:
	if effect_ids.is_empty():
		return null
	var success_events = trigger_dispatcher.collect_events(
		ContentSchemaScript.TRIGGER_FIELD_APPLY_SUCCESS,
		battle_state,
		content_index,
		effect_ids,
		context_resolver.resolve_field_creator(effect_event),
		effect_event.source_instance_id,
		effect_event.source_kind_order,
		effect_event.source_order_speed_snapshot,
		effect_event.chain_context
	)
	if success_events.is_empty():
		return null
	return trigger_batch_runner.execute_trigger_batch(
		"__field_apply_success__",
		battle_state,
		content_index,
		[],
		battle_state.chain_context,
		success_events
	)
