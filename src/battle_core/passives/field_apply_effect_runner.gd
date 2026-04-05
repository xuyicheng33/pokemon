extends RefCounted
class_name FieldApplyEffectRunner

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var field_service
var trigger_dispatcher
var id_factory
var context_resolver
var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	if field_service == null:
		return "field_service"
	if trigger_dispatcher == null:
		return "trigger_dispatcher"
	if id_factory == null:
		return "id_factory"
	if context_resolver == null:
		return "context_resolver"
	return ""

func create_field_state(effect_definition, payload, effect_event) -> Variant:
	last_invalid_battle_code = null
	var field_state = FieldStateScript.new()
	field_state.field_def_id = payload.field_definition_id
	field_state.instance_id = id_factory.next_id("field")
	field_state.creator = context_resolver.resolve_field_creator(effect_event)
	if field_state.creator.is_empty():
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return null
	field_state.remaining_turns = effect_definition.duration
	field_state.source_instance_id = effect_event.source_instance_id
	field_state.source_kind_order = effect_event.source_kind_order
	field_state.source_order_speed_snapshot = effect_event.source_order_speed_snapshot
	return field_state

func execute_field_effects(
	trigger_name: String,
	field_state,
	battle_state,
	content_index,
	chain_context,
	execute_trigger_batch: Callable = Callable()
) -> Variant:
	var field_definition = field_service.get_field_definition_for_state(field_state, content_index)
	if field_definition == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return last_invalid_battle_code
	if field_definition.effect_ids.is_empty():
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
	if not execute_trigger_batch.is_valid():
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return ErrorCodesScript.INVALID_STATE_CORRUPTION
	return execute_trigger_batch.call(
		"__field_%s__" % trigger_name,
		battle_state,
		content_index,
		[],
		battle_state.chain_context,
		effect_events
	)

func execute_success_effects(
	effect_ids: PackedStringArray,
	effect_event,
	battle_state,
	content_index,
	execute_trigger_batch: Callable = Callable()
) -> Variant:
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
	var trigger_invalid_code = trigger_dispatcher.invalid_battle_code()
	if trigger_invalid_code != null:
		return trigger_invalid_code
	if success_events.is_empty():
		return null
	if not execute_trigger_batch.is_valid():
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return ErrorCodesScript.INVALID_STATE_CORRUPTION
	return execute_trigger_batch.call(
		"__field_apply_success__",
		battle_state,
		content_index,
		[],
		battle_state.chain_context,
		success_events
	)

func defer_success_effects(field_state, effect_ids: PackedStringArray, effect_event) -> void:
	if field_state == null or effect_ids.is_empty() or effect_event == null:
		return
	field_state.pending_success_effect_ids = effect_ids.duplicate()
	field_state.pending_success_source_instance_id = String(effect_event.source_instance_id)
	field_state.pending_success_source_kind_order = int(effect_event.source_kind_order)
	field_state.pending_success_source_order_speed_snapshot = int(effect_event.source_order_speed_snapshot)
	field_state.pending_success_chain_context = effect_event.chain_context.copy_shallow() if effect_event.chain_context != null else null

func execute_pending_success_effects(
	field_state,
	battle_state,
	content_index,
	execute_trigger_batch: Callable = Callable()
) -> Variant:
	if field_state == null or field_state.pending_success_effect_ids.is_empty():
		return null
	var success_events = trigger_dispatcher.collect_events(
		ContentSchemaScript.TRIGGER_FIELD_APPLY_SUCCESS,
		battle_state,
		content_index,
		field_state.pending_success_effect_ids,
		String(field_state.creator),
		field_state.pending_success_source_instance_id,
		field_state.pending_success_source_kind_order,
		field_state.pending_success_source_order_speed_snapshot,
		field_state.pending_success_chain_context
	)
	var trigger_invalid_code = trigger_dispatcher.invalid_battle_code()
	if trigger_invalid_code != null:
		clear_pending_success_effects(field_state)
		return trigger_invalid_code
	clear_pending_success_effects(field_state)
	if success_events.is_empty():
		return null
	if not execute_trigger_batch.is_valid():
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return ErrorCodesScript.INVALID_STATE_CORRUPTION
	return execute_trigger_batch.call(
		"__field_apply_success__",
		battle_state,
		content_index,
		[],
		battle_state.chain_context,
		success_events
	)

func clear_pending_success_effects(field_state) -> void:
	if field_state == null:
		return
	field_state.pending_success_effect_ids = PackedStringArray()
	field_state.pending_success_source_instance_id = ""
	field_state.pending_success_source_kind_order = 0
	field_state.pending_success_source_order_speed_snapshot = 0
	field_state.pending_success_chain_context = null
