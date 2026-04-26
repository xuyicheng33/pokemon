extends RefCounted
class_name TurnEndPhaseService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "turn_field_lifecycle_service",
		"source": "turn_field_lifecycle_service",
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
		"field": "effect_instance_service",
		"source": "effect_instance_service",
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

const TurnExpiryDecrementHelperScript := preload("res://src/battle_core/turn/turn_expiry_decrement_helper.gd")

var turn_field_lifecycle_service: TurnFieldLifecycleService
var trigger_batch_runner: TriggerBatchRunner
var effect_instance_dispatcher: EffectInstanceDispatcher
var effect_instance_service: EffectInstanceService
var rule_mod_service: RuleModService
var faint_resolver: FaintResolver
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var battle_result_service: BattleResultService
var _decrement_helper = TurnExpiryDecrementHelperScript.new()

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)

func execute_phase(battle_state: BattleState, content_index: BattleContentIndex, cause_event_id: String, turn_end_event = null) -> Dictionary:
	_sync_decrement_helper()
	if _execute_system_trigger_batch("turn_end", battle_state, content_index):
		return {"terminated": true, "field_change": null}
	var field_tick_result = turn_field_lifecycle_service.apply_turn_end_field_tick(
		battle_state,
		content_index,
		cause_event_id
	)
	var field_change = field_tick_result.get("field_change", null)
	if bool(field_tick_result.get("terminated", false)):
		return {"terminated": true, "field_change": field_change}
	if _decrement_helper.decrement_effect_instances_and_log(
		battle_state,
		content_index,
		"turn_end",
		_decrement_helper.collect_effect_decrement_owner_ids(battle_state),
		cause_event_id
	):
		return {"terminated": true, "field_change": field_change}
	_decrement_helper.decrement_rule_mods_and_log(battle_state, "turn_end", cause_event_id)
	if turn_end_event != null:
		turn_end_event.field_change = field_change
	var faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
	if faint_invalid_code != null:
		battle_result_service.terminate_invalid_battle(battle_state, str(faint_invalid_code))
		return {"terminated": true, "field_change": field_change}
	if turn_field_lifecycle_service.break_field_if_creator_inactive(battle_state, content_index):
		return {"terminated": true, "field_change": field_change}
	if turn_field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index):
		return {"terminated": true, "field_change": field_change}
	if battle_result_service.resolve_standard_victory(battle_state):
		return {"terminated": true, "field_change": field_change}
	return {"terminated": false, "field_change": field_change}

func _execute_system_trigger_batch(trigger_name: String, battle_state: BattleState, content_index: BattleContentIndex) -> bool:
	var invalid_code = trigger_batch_runner.execute_trigger_batch(
		trigger_name,
		battle_state,
		content_index,
		turn_field_lifecycle_service.collect_active_unit_ids(battle_state),
		battle_state.current_chain_context()
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

func _sync_decrement_helper() -> void:
	_decrement_helper.turn_field_lifecycle_service = turn_field_lifecycle_service
	_decrement_helper.effect_instance_dispatcher = effect_instance_dispatcher
	_decrement_helper.effect_instance_service = effect_instance_service
	_decrement_helper.trigger_batch_runner = trigger_batch_runner
	_decrement_helper.rule_mod_service = rule_mod_service
	_decrement_helper.battle_logger = battle_logger
	_decrement_helper.log_event_builder = log_event_builder
	_decrement_helper.battle_result_service = battle_result_service
