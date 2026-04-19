extends RefCounted
class_name ReplacementService
const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")
const DefaultReplacementSelectorScript := preload("res://src/battle_core/lifecycle/default_replacement_selector.gd")

const COMPOSE_DEPS := [
	{"field": "battle_logger", "source": "battle_logger", "nested": true},
	{"field": "log_event_builder", "source": "log_event_builder", "nested": true},
	{"field": "leave_service", "source": "leave_service", "nested": true},
	{"field": "field_service", "source": "field_service", "nested": true},
]
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ReplacementSelectionHelperScript := preload("res://src/battle_core/lifecycle/replacement_selection_helper.gd")
const ReplacementEntryHelperScript := preload("res://src/battle_core/lifecycle/replacement_entry_helper.gd")
var battle_logger
var log_event_builder
var leave_service
var field_service
var replacement_selector = DefaultReplacementSelectorScript.new()
var _selection_helper = ReplacementSelectionHelperScript.new()
var _entry_helper = ReplacementEntryHelperScript.new()

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func resolve_replacement(battle_state, side_state, reason: String) -> Dictionary:
	var legal_bench_ids := _selection_helper.collect_legal_bench_ids(battle_state, side_state)
	if legal_bench_ids.is_empty():
		return _resolve_result(null, null)
	var selected_unit_id: String = _selection_helper.select_replacement_unit_id(
		battle_state,
		side_state,
		legal_bench_ids,
		reason,
		replacement_selector
	)
	if selected_unit_id.is_empty():
		return _resolve_result(null, ErrorCodesScript.INVALID_REPLACEMENT_SELECTION)
	var entered_unit = _entry_helper.enter_replacement(
		battle_state,
		side_state,
		ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
		selected_unit_id,
		battle_logger,
		log_event_builder
	)
	if entered_unit == null:
		return _resolve_result(null, ErrorCodesScript.INVALID_REPLACEMENT_SELECTION)
	return _resolve_result(entered_unit, null)

func execute_replacement_lifecycle(
	battle_state,
	content_index,
	target_unit_id: String,
	selected_unit_id: String,
	leave_reason: String,
	execute_trigger_batch: Callable = Callable()
) -> Dictionary:
	var target_unit = battle_state.get_unit(target_unit_id)
	if target_unit == null or target_unit.current_hp <= 0 or target_unit.leave_state != LeaveStatesScript.ACTIVE:
		return _replacement_result(false, null, null)
	var side_state = battle_state.get_side_for_unit(target_unit_id)
	if side_state == null:
		return _replacement_result(false, null, ErrorCodesScript.INVALID_STATE_CORRUPTION)
	var active_slot_id: String = _selection_helper.find_active_slot_id(side_state, target_unit_id)
	if active_slot_id.is_empty():
		return _replacement_result(false, null, null)
	var selected_unit = battle_state.get_unit(selected_unit_id)
	if selected_unit == null or selected_unit.current_hp <= 0 or not side_state.has_bench_unit(selected_unit_id):
		return _replacement_result(false, null, ErrorCodesScript.INVALID_REPLACEMENT_SELECTION)
	var on_switch_invalid_code = _execute_lifecycle_trigger_batch(
		"on_switch",
		battle_state,
		content_index,
		[target_unit.unit_instance_id],
		execute_trigger_batch
	)
	if on_switch_invalid_code != null:
		return _replacement_result(false, null, on_switch_invalid_code)
	var on_exit_invalid_code = _execute_lifecycle_trigger_batch(
		"on_exit",
		battle_state,
		content_index,
		[target_unit.unit_instance_id],
		execute_trigger_batch
	)
	if on_exit_invalid_code != null:
		return _replacement_result(false, null, on_exit_invalid_code)
	side_state.bench_order.append(target_unit.unit_instance_id)
	leave_service.leave_unit(battle_state, target_unit, leave_reason, content_index)
	if leave_service.invalid_battle_code() != null:
		return _replacement_result(false, null, leave_service.invalid_battle_code())
	var field_break_invalid_code = field_service.break_field_if_creator_inactive(
		battle_state,
		content_index,
		battle_state.chain_context,
		execute_trigger_batch
	)
	if field_break_invalid_code != null:
		return _replacement_result(false, null, field_break_invalid_code)
	var entered_unit = _entry_helper.enter_replacement(
		battle_state,
		side_state,
		active_slot_id,
		selected_unit_id,
		battle_logger,
		log_event_builder
	)
	if entered_unit == null:
		return _replacement_result(false, null, ErrorCodesScript.INVALID_REPLACEMENT_SELECTION)
	var on_enter_invalid_code = _execute_lifecycle_trigger_batch(
		"on_enter",
		battle_state,
		content_index,
		[entered_unit.unit_instance_id],
		execute_trigger_batch
	)
	if on_enter_invalid_code != null:
		return _replacement_result(false, entered_unit, on_enter_invalid_code)
	return _replacement_result(true, entered_unit, null)

func execute_forced_replace(
	battle_state,
	content_index,
	target_unit_id: String,
	selector_reason: String = "forced_replace",
	execute_trigger_batch: Callable = Callable()
) -> Dictionary:
	var target_unit = battle_state.get_unit(target_unit_id)
	if target_unit == null or target_unit.current_hp <= 0 or target_unit.leave_state != LeaveStatesScript.ACTIVE:
		return _replacement_result(false, null, null)
	var side_state = battle_state.get_side_for_unit(target_unit_id)
	if side_state == null:
		return _replacement_result(false, null, ErrorCodesScript.INVALID_STATE_CORRUPTION)
	var active_slot_id: String = _selection_helper.find_active_slot_id(side_state, target_unit_id)
	if active_slot_id.is_empty():
		return _replacement_result(false, null, null)
	var legal_bench_ids := _selection_helper.collect_legal_bench_ids(battle_state, side_state)
	if legal_bench_ids.is_empty():
		return _replacement_result(false, null, null)
	var selected_unit_id: String = _selection_helper.select_replacement_unit_id(
		battle_state,
		side_state,
		legal_bench_ids,
		selector_reason,
		replacement_selector
	)
	if selected_unit_id.is_empty():
		return _replacement_result(false, null, ErrorCodesScript.INVALID_REPLACEMENT_SELECTION)
	var selected_unit = battle_state.get_unit(selected_unit_id)
	if selected_unit == null or selected_unit.current_hp <= 0 or not side_state.has_bench_unit(selected_unit_id):
		return _replacement_result(false, null, ErrorCodesScript.INVALID_REPLACEMENT_SELECTION)
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.STATE_SWITCH,
		battle_state,
		{
			"source_instance_id": target_unit.unit_instance_id,
			"target_instance_id": selected_unit.unit_instance_id,
			"target_slot": active_slot_id,
			"leave_reason": "forced_replace",
			"trigger_name": "on_switch",
			"payload_summary": "%s forced replaced to %s" % [target_unit.public_id, selected_unit.public_id],
		}
	))
	return execute_replacement_lifecycle(
		battle_state,
		content_index,
		target_unit_id,
		selected_unit_id,
		"forced_replace",
		execute_trigger_batch
	)

func _execute_lifecycle_trigger_batch(
	trigger_name: String,
	battle_state,
	content_index,
	owner_unit_ids: Array,
	execute_trigger_batch: Callable = Callable()
) -> Variant:
	if not execute_trigger_batch.is_valid():
		return ErrorCodesScript.INVALID_STATE_CORRUPTION
	return execute_trigger_batch.call(
		trigger_name,
		battle_state,
		content_index,
		owner_unit_ids,
		battle_state.chain_context
	)

func _resolve_result(entered_unit, invalid_code) -> Dictionary:
	return {"entered_unit": entered_unit, "invalid_code": invalid_code}

func _replacement_result(replaced: bool, entered_unit, invalid_code) -> Dictionary:
	return {"replaced": replaced, "entered_unit": entered_unit, "invalid_code": invalid_code}
