extends RefCounted
class_name TurnStartPhaseService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "turn_field_lifecycle_service",
		"source": "turn_field_lifecycle_service",
		"nested": true,
	},
	{
		"field": "mp_service",
		"source": "mp_service",
		"nested": true,
	},
	{
		"field": "trigger_batch_runner",
		"source": "trigger_batch_runner",
		"nested": true,
	},
	{
		"field": "effect_instance_dispatcher",
		"source": "effect_instance_dispatcher",
		"nested": true,
	},
	{
		"field": "rule_mod_service",
		"source": "rule_mod_service",
		"nested": true,
	},
	{
		"field": "faint_resolver",
		"source": "faint_resolver",
		"nested": true,
	},
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
		"field": "battle_result_service",
		"source": "battle_result_service",
		"nested": true,
	},
]

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ValueChangeFactoryScript := preload("res://src/battle_core/contracts/value_change_factory.gd")

var turn_field_lifecycle_service
var mp_service
var trigger_batch_runner
var effect_instance_dispatcher
var rule_mod_service
var faint_resolver
var battle_logger
var log_event_builder
var battle_result_service

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func apply_turn_start_regen(battle_state, cause_event_id: String) -> void:
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		if active_unit == null or active_unit.current_hp <= 0:
			continue
		var before_mp: int = active_unit.current_mp
		var regen_value: int = rule_mod_service.resolve_mp_regen_value(
			battle_state,
			active_unit.unit_instance_id,
			active_unit.regen_per_turn
		)
		active_unit.current_mp = mp_service.apply_turn_start_regen(
			active_unit.current_mp,
			regen_value,
			active_unit.max_mp
		)
		if before_mp == active_unit.current_mp:
			continue
		var value_change = ValueChangeFactoryScript.create(
			active_unit.unit_instance_id,
			"mp",
			before_mp,
			active_unit.current_mp
		)
		var log_event = log_event_builder.build_effect_event(
			EventTypesScript.EFFECT_RESOURCE_MOD,
			battle_state,
			cause_event_id,
			{
				"source_instance_id": "system:turn_start",
				"target_instance_id": active_unit.unit_instance_id,
				"trigger_name": "turn_start",
				"value_changes": [value_change],
				"payload_summary": "%s regenerated %d mp" % [active_unit.public_id, value_change.delta],
			}
		)
		battle_logger.append_event(log_event)

func execute_phase(battle_state, content_index, cause_event_id: String) -> bool:
	if _execute_system_trigger_batch("turn_start", battle_state, content_index):
		return true
	if turn_field_lifecycle_service.break_field_if_creator_inactive(battle_state, content_index):
		return true
	if turn_field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index):
		return true
	if _decrement_effect_instances_and_log(
		battle_state,
		content_index,
		"turn_start",
		collect_effect_decrement_owner_ids(battle_state),
		cause_event_id
	):
		return true
	_decrement_rule_mods_and_log(battle_state, "turn_start", cause_event_id)
	if battle_result_service.resolve_standard_victory(battle_state):
		return true
	return false

func collect_effect_decrement_owner_ids(battle_state) -> Array:
	var owner_ids: Array = turn_field_lifecycle_service.collect_active_unit_ids(battle_state)
	var seen_owner_ids: Dictionary = {}
	for owner_id in owner_ids:
		seen_owner_ids[str(owner_id)] = true
	for side_state in battle_state.sides:
		for unit_state in side_state.team_units:
			if unit_state == null:
				continue
			var unit_id := String(unit_state.unit_instance_id)
			if seen_owner_ids.has(unit_id):
				continue
			if not _unit_has_persistent_effect(unit_state):
				continue
			owner_ids.append(unit_id)
			seen_owner_ids[unit_id] = true
	return owner_ids

func _execute_system_trigger_batch(trigger_name: String, battle_state, content_index) -> bool:
	var invalid_code = trigger_batch_runner.execute_trigger_batch(
		trigger_name,
		battle_state,
		content_index,
		turn_field_lifecycle_service.collect_active_unit_ids(battle_state),
		battle_state.chain_context
	)
	if invalid_code != null:
		battle_result_service.terminate_invalid_battle(battle_state, str(invalid_code))
		return true
	var faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
	if faint_invalid_code != null:
		battle_result_service.terminate_invalid_battle(battle_state, str(faint_invalid_code))
		return true
	if battle_result_service.resolve_standard_victory(battle_state):
		return true
	return false

func _decrement_rule_mods_and_log(battle_state, trigger_name: String, cause_event_id: String) -> void:
	var removed_instances: Array = rule_mod_service.decrement_for_trigger(battle_state, trigger_name)
	for removed in removed_instances:
		var removed_instance = removed["instance"]
		var log_event = log_event_builder.build_effect_event(
			EventTypesScript.EFFECT_RULE_MOD_REMOVE,
			battle_state,
			cause_event_id,
			{
				"source_instance_id": removed_instance.instance_id,
				"target_instance_id": removed["owner_id"],
				"priority": removed_instance.priority,
				"trigger_name": trigger_name,
				"payload_summary": "rule mod expired: %s" % removed_instance.mod_kind,
			}
		)
		battle_logger.append_event(log_event)

func _decrement_effect_instances_and_log(battle_state, content_index, trigger_name: String, owner_unit_ids: Array, cause_event_id: String) -> bool:
	var decrement_result: Dictionary = effect_instance_dispatcher.decrement_for_trigger(
		trigger_name,
		battle_state,
		content_index,
		owner_unit_ids
	)
	var decrement_invalid_code = decrement_result.get("invalid_code", null)
	if decrement_invalid_code != null:
		battle_result_service.terminate_invalid_battle(battle_state, str(decrement_invalid_code))
		return true
	var removed_instances: Array = decrement_result.get("removed_instances", [])
	var expire_events: Array = decrement_result.get("expire_events", [])
	if not expire_events.is_empty():
		var expire_invalid_code = trigger_batch_runner.execute_trigger_batch(
			"__effect_expire__",
			battle_state,
			content_index,
			[],
			battle_state.chain_context,
			expire_events
		)
		if expire_invalid_code != null:
			battle_result_service.terminate_invalid_battle(battle_state, str(expire_invalid_code))
			return true
	for removed in removed_instances:
		var removed_instance = removed["instance"]
		var effect_definition = removed["definition"]
		var log_event = log_event_builder.build_effect_event(
			EventTypesScript.EFFECT_REMOVE_EFFECT,
			battle_state,
			cause_event_id,
			{
				"source_instance_id": removed_instance.source_instance_id,
				"target_instance_id": removed["owner_id"],
				"priority": effect_definition.priority,
				"trigger_name": trigger_name,
				"payload_summary": "effect expired: %s" % effect_definition.id,
			}
		)
		battle_logger.append_event(log_event)
	return false

func _unit_has_persistent_effect(unit_state) -> bool:
	if unit_state == null:
		return false
	for effect_instance in unit_state.effect_instances:
		if bool(effect_instance.persists_on_switch):
			return true
	return false
