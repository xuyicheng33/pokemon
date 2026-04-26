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
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var leave_service: LeaveService
var field_service: FieldService
var replacement_selector = DefaultReplacementSelectorScript.new()
var _selection_helper = ReplacementSelectionHelperScript.new()
var _entry_helper = ReplacementEntryHelperScript.new()

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func resolve_replacement(battle_state: BattleState, side_state, reason: String) -> Dictionary:
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
	battle_state: BattleState,
	content_index: BattleContentIndex,
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
	var replacement_snapshot := _snapshot_replacement_runtime(battle_state, side_state, target_unit, selected_unit)
	side_state.bench_order.append(target_unit.unit_instance_id)
	leave_service.leave_unit(battle_state, target_unit, leave_reason, content_index)
	if leave_service.invalid_battle_code() != null:
		_restore_replacement_runtime(replacement_snapshot, battle_state, side_state, target_unit, selected_unit)
		return _replacement_result(false, null, leave_service.invalid_battle_code())
	var field_break_invalid_code = field_service.break_field_if_creator_inactive(
		battle_state,
		content_index,
		battle_state.chain_context,
		execute_trigger_batch
	)
	if field_break_invalid_code != null:
		_restore_replacement_runtime(replacement_snapshot, battle_state, side_state, target_unit, selected_unit)
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
		_restore_replacement_runtime(replacement_snapshot, battle_state, side_state, target_unit, selected_unit)
		return _replacement_result(false, null, ErrorCodesScript.INVALID_REPLACEMENT_SELECTION)
	var on_enter_invalid_code = _execute_lifecycle_trigger_batch(
		"on_enter",
		battle_state,
		content_index,
		[entered_unit.unit_instance_id],
		execute_trigger_batch
	)
	if on_enter_invalid_code != null:
		_restore_replacement_runtime(replacement_snapshot, battle_state, side_state, target_unit, selected_unit)
		return _replacement_result(false, entered_unit, on_enter_invalid_code)
	return _replacement_result(true, entered_unit, null)

func execute_forced_replace(
	battle_state: BattleState,
	content_index: BattleContentIndex,
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
	var replace_result: Dictionary = execute_replacement_lifecycle(
		battle_state,
		content_index,
		target_unit_id,
		selected_unit_id,
		"forced_replace",
		execute_trigger_batch
	)
	if replace_result.get("invalid_code", null) == null and bool(replace_result.get("replaced", false)):
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
	return replace_result

func _execute_lifecycle_trigger_batch(
	trigger_name: String,
	battle_state: BattleState,
	content_index: BattleContentIndex,
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

func _snapshot_replacement_runtime(battle_state: BattleState, side_state, target_unit, selected_unit) -> Dictionary:
	return {
		"bench_order": side_state.bench_order.duplicate(),
		"active_slots": side_state.active_slots.duplicate(true),
		"target_effect_instances": target_unit.effect_instances.duplicate(),
		"target_rule_mod_instances": target_unit.rule_mod_instances.duplicate(),
		"target_stat_stages": target_unit.stat_stages.duplicate(true),
		"target_persistent_stat_stages": target_unit.persistent_stat_stages.duplicate(true),
		"target_has_acted": target_unit.has_acted,
		"target_action_window_passed": target_unit.action_window_passed,
		"target_leave_reason": target_unit.leave_reason,
		"target_leave_state": target_unit.leave_state,
		"target_current_hp": target_unit.current_hp,
		"target_reentered_turn_index": target_unit.reentered_turn_index,
		"selected_has_acted": selected_unit.has_acted,
		"selected_action_window_passed": selected_unit.action_window_passed,
		"selected_leave_reason": selected_unit.leave_reason,
		"selected_leave_state": selected_unit.leave_state,
		"selected_reentered_turn_index": selected_unit.reentered_turn_index,
		"field_state": battle_state.field_state,
		"field_rule_mod_instances": battle_state.field_rule_mod_instances.duplicate(),
		"battle_log_size": battle_logger.event_log.size() if battle_logger != null else 0,
	}

func _restore_replacement_runtime(snapshot: Dictionary, battle_state: BattleState, side_state, target_unit, selected_unit) -> void:
	side_state.bench_order = PackedStringArray(snapshot.get("bench_order", PackedStringArray()))
	side_state.active_slots = snapshot.get("active_slots", {}).duplicate(true)
	target_unit.effect_instances = snapshot.get("target_effect_instances", []).duplicate()
	target_unit.rule_mod_instances = snapshot.get("target_rule_mod_instances", []).duplicate()
	target_unit.stat_stages = snapshot.get("target_stat_stages", {}).duplicate(true)
	target_unit.persistent_stat_stages = snapshot.get("target_persistent_stat_stages", {}).duplicate(true)
	target_unit.has_acted = bool(snapshot.get("target_has_acted", false))
	target_unit.action_window_passed = bool(snapshot.get("target_action_window_passed", false))
	target_unit.leave_reason = snapshot.get("target_leave_reason", null)
	target_unit.leave_state = String(snapshot.get("target_leave_state", LeaveStatesScript.ACTIVE))
	target_unit.current_hp = int(snapshot.get("target_current_hp", target_unit.current_hp))
	target_unit.reentered_turn_index = int(snapshot.get("target_reentered_turn_index", -1))
	selected_unit.has_acted = bool(snapshot.get("selected_has_acted", false))
	selected_unit.action_window_passed = bool(snapshot.get("selected_action_window_passed", false))
	selected_unit.leave_reason = snapshot.get("selected_leave_reason", null)
	selected_unit.leave_state = String(snapshot.get("selected_leave_state", selected_unit.leave_state))
	selected_unit.reentered_turn_index = int(snapshot.get("selected_reentered_turn_index", -1))
	battle_state.field_state = snapshot.get("field_state", null)
	battle_state.field_rule_mod_instances = snapshot.get("field_rule_mod_instances", []).duplicate()
	if battle_logger != null:
		battle_logger.event_log.resize(int(snapshot.get("battle_log_size", battle_logger.event_log.size())))
