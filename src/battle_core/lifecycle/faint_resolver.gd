extends RefCounted
class_name FaintResolver

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")
const FaintLeaveReplacementServiceScript := preload("res://src/battle_core/lifecycle/faint_leave_replacement_service.gd")

const COMPOSE_DEPS := [
	{"field": "trigger_batch_runner", "source": "trigger_batch_runner", "nested": true},
	{"field": "battle_logger", "source": "battle_logger", "nested": true},
	{"field": "log_event_builder", "source": "log_event_builder", "nested": true},
	{"field": "faint_killer_attribution_service", "source": "faint_killer_attribution_service", "nested": true},
	{"field": "field_service", "source": "field_service", "nested": true},
	{"field": "leave_service", "source": "leave_service"},
	{"field": "replacement_service", "source": "replacement_service"},
]

const EventTypesScript := preload("res://src/shared/event_types.gd")

var trigger_batch_runner: TriggerBatchRunner
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var faint_killer_attribution_service: FaintKillerAttributionService
var field_service: FieldService
var leave_service: LeaveService
var replacement_service: ReplacementService
var faint_leave_replacement_service: FaintLeaveReplacementService

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)

func _compose_post_wire() -> void:
	faint_leave_replacement_service = FaintLeaveReplacementServiceScript.new()
	faint_leave_replacement_service.leave_service = leave_service
	faint_leave_replacement_service.replacement_service = replacement_service


func resolve_faint_window(battle_state: BattleState, content_index: BattleContentIndex) -> Variant:
	while true:
		var fainted_units: Array = faint_leave_replacement_service.collect_pending_fainted_units(battle_state)

		if not fainted_units.is_empty():
			var faint_invalid_code = _resolve_fainted_units_and_exit(battle_state, content_index, fainted_units)
			if faint_invalid_code != null:
				return faint_invalid_code

		var replacement_resolution: Dictionary = faint_leave_replacement_service.resolve_faint_replacements(battle_state)
		var replacement_invalid_code = replacement_resolution.get("invalid_code", null)
		if replacement_invalid_code != null:
			return replacement_invalid_code
		var entered_unit_ids: Array = replacement_resolution.get("entered_unit_ids", [])
		if not entered_unit_ids.is_empty():
			var on_enter_invalid_code = _execute_unit_trigger_batch("on_enter", battle_state, content_index, entered_unit_ids)
			if on_enter_invalid_code != null:
				return on_enter_invalid_code
		if not faint_leave_replacement_service.has_pending_faint_active(battle_state):
			break
	return null

func _resolve_fainted_units_and_exit(battle_state: BattleState, content_index: BattleContentIndex, fainted_units: Array) -> Variant:
	var fainted_unit_ids: Array = faint_leave_replacement_service.collect_unit_ids(fainted_units)
	var killer_by_target: Dictionary = {}
	for fainted_unit_id in fainted_unit_ids:
		killer_by_target[fainted_unit_id] = faint_killer_attribution_service.resolve_killer_for_target(battle_state, fainted_unit_id)
	for fainted_unit in fainted_units:
		battle_logger.append_event(log_event_builder.build_event(
			EventTypesScript.STATE_FAINT,
			battle_state,
			{
				"source_instance_id": fainted_unit.unit_instance_id,
				"target_instance_id": fainted_unit.unit_instance_id,
				"leave_reason": "faint",
				"killer_id": killer_by_target.get(fainted_unit.unit_instance_id, null),
				"trigger_name": "on_faint",
				"payload_summary": "%s fainted" % fainted_unit.public_id,
			}
		))
	var on_faint_invalid_code = _execute_unit_trigger_batch("on_faint", battle_state, content_index, fainted_unit_ids)
	if on_faint_invalid_code != null:
		return on_faint_invalid_code
	var killer_resolution: Dictionary = faint_killer_attribution_service.resolve_killer_units(battle_state, fainted_unit_ids)
	var killer_unit_ids: Array = killer_resolution["killer_unit_ids"]
	if not killer_unit_ids.is_empty():
		var action_on_kill_events_result: Dictionary = faint_killer_attribution_service.collect_action_on_kill_events(
			battle_state,
			content_index,
			killer_unit_ids
		)
		if action_on_kill_events_result["invalid_code"] != null:
			return action_on_kill_events_result["invalid_code"]
		# on_kill 派发沿用主链 chain_context（含 actor_id），不为 effect 链触发的击杀重写
		# 链上下文：action 自带的 `effects_on_kill_ids` 只有在“actor_id 自身就是真正的
		# killer”时才补进 extra_effect_events（见 FaintKillerAttributionService），
		# effect 链（中毒、反伤、领域 tick 等）造成的致命伤害不归到 effect 源头“计 kill”，
		# 避免被动伤害冒充主动击杀污染 on_kill 语义。
		var on_kill_invalid_code = _execute_unit_trigger_batch(
			"on_kill",
			battle_state,
			content_index,
			killer_unit_ids,
			action_on_kill_events_result["events"]
		)
		if on_kill_invalid_code != null:
			return on_kill_invalid_code
	var on_exit_invalid_code = _execute_unit_trigger_batch("on_exit", battle_state, content_index, fainted_unit_ids)
	if on_exit_invalid_code != null:
		return on_exit_invalid_code
	var exit_invalid_code = faint_leave_replacement_service.resolve_fainted_units_leave(
		battle_state,
		content_index,
		fainted_units
	)
	if exit_invalid_code != null:
		return exit_invalid_code
	var field_break_invalid_code = _execute_field_break_if_creator_inactive(battle_state, content_index)
	if field_break_invalid_code != null:
		return field_break_invalid_code
	faint_killer_attribution_service.clear_fatal_damage_records(battle_state, fainted_unit_ids)
	return null

func _execute_unit_trigger_batch(trigger_name: String, battle_state: BattleState, content_index: BattleContentIndex, owner_unit_ids: Array, extra_effect_events: Array = []) -> Variant:
	return trigger_batch_runner.execute_trigger_batch(
		trigger_name,
		battle_state,
		content_index,
		owner_unit_ids,
		battle_state.current_chain_context(),
		extra_effect_events
	)

func _execute_field_break_if_creator_inactive(battle_state: BattleState, content_index: BattleContentIndex) -> Variant:
	if field_service == null:
		return null
	return field_service.break_field_if_creator_inactive(
		battle_state,
		content_index,
		battle_state.current_chain_context(),
		Callable(trigger_batch_runner, "execute_trigger_batch")
	)
