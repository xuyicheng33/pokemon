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
const TurnStartExpiryServiceScript := preload("res://src/battle_core/turn/turn_start_expiry_service.gd")
const TurnStartRegenServiceScript := preload("res://src/battle_core/turn/turn_start_regen_service.gd")

var turn_field_lifecycle_service: TurnFieldLifecycleService
var mp_service: MpService
var trigger_batch_runner: TriggerBatchRunner
var effect_instance_dispatcher: EffectInstanceDispatcher
var rule_mod_service: RuleModService
var faint_resolver: FaintResolver
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var battle_result_service: BattleResultService
var _expiry_service = TurnStartExpiryServiceScript.new()
var _regen_service = TurnStartRegenServiceScript.new()

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func apply_turn_start_regen(battle_state: BattleState, cause_event_id: String) -> void:
	_sync_helper_dependencies()
	_regen_service.apply_turn_start_regen(battle_state, cause_event_id)

func execute_phase(battle_state: BattleState, content_index: BattleContentIndex, cause_event_id: String) -> bool:
	_sync_helper_dependencies()
	if _execute_system_trigger_batch("turn_start", battle_state, content_index):
		return true
	if turn_field_lifecycle_service.break_field_if_creator_inactive(battle_state, content_index):
		return true
	if turn_field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index):
		return true
	if _expiry_service.execute_expiry_phase(battle_state, content_index, "turn_start", cause_event_id):
		return true
	var faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
	if faint_invalid_code != null:
		battle_result_service.terminate_invalid_battle(battle_state, str(faint_invalid_code))
		return true
	if battle_result_service.resolve_standard_victory(battle_state):
		return true
	return false

func _execute_system_trigger_batch(trigger_name: String, battle_state: BattleState, content_index: BattleContentIndex) -> bool:
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

func _sync_helper_dependencies() -> void:
	_regen_service.mp_service = mp_service
	_regen_service.rule_mod_service = rule_mod_service
	_regen_service.battle_logger = battle_logger
	_regen_service.log_event_builder = log_event_builder
	_expiry_service.turn_field_lifecycle_service = turn_field_lifecycle_service
	_expiry_service.effect_instance_dispatcher = effect_instance_dispatcher
	_expiry_service.trigger_batch_runner = trigger_batch_runner
	_expiry_service.rule_mod_service = rule_mod_service
	_expiry_service.battle_logger = battle_logger
	_expiry_service.log_event_builder = log_event_builder
	_expiry_service.battle_result_service = battle_result_service
