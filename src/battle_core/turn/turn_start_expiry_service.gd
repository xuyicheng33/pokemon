extends RefCounted
class_name TurnStartExpiryService

const TurnExpiryDecrementHelperScript := preload("res://src/battle_core/turn/turn_expiry_decrement_helper.gd")

var turn_field_lifecycle_service: TurnFieldLifecycleService
var effect_instance_dispatcher: EffectInstanceDispatcher
var effect_instance_service: EffectInstanceService
var trigger_batch_runner: TriggerBatchRunner
var rule_mod_service: RuleModService
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var battle_result_service: BattleResultService
var _decrement_helper = TurnExpiryDecrementHelperScript.new()

func execute_expiry_phase(battle_state: BattleState, content_index: BattleContentIndex, trigger_name: String, cause_event_id: String) -> bool:
	_sync_decrement_helper()
	var owner_unit_ids: Array = _decrement_helper.collect_effect_decrement_owner_ids(battle_state)
	if _decrement_helper.decrement_effect_instances_and_log(
		battle_state,
		content_index,
		trigger_name,
		owner_unit_ids,
		cause_event_id
	):
		return true
	_decrement_helper.decrement_rule_mods_and_log(battle_state, trigger_name, cause_event_id)
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
