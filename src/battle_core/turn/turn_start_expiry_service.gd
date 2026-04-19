extends RefCounted
class_name TurnStartExpiryService

const EventTypesScript := preload("res://src/shared/event_types.gd")

var turn_field_lifecycle_service: TurnFieldLifecycleService
var effect_instance_dispatcher: EffectInstanceDispatcher
var trigger_batch_runner: TriggerBatchRunner
var rule_mod_service: RuleModService
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var battle_result_service: BattleResultService

func execute_expiry_phase(battle_state, content_index, trigger_name: String, cause_event_id: String) -> bool:
	var owner_unit_ids: Array = collect_effect_decrement_owner_ids(battle_state)
	if _decrement_effect_instances_and_log(
		battle_state,
		content_index,
		trigger_name,
		owner_unit_ids,
		cause_event_id
	):
		return true
	_decrement_rule_mods_and_log(battle_state, trigger_name, cause_event_id)
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
