extends RefCounted
class_name BattleResultService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "id_factory",
		"source": "id_factory",
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
		"field": "turn_limit_scoring_service",
		"source": "turn_limit_scoring_service",
		"nested": true,
	},
]

const ChainBuilderScript := preload("res://src/battle_core/turn/battle_result_service_chain_builder.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const OutcomeResolverScript := preload("res://src/battle_core/turn/battle_result_service_outcome_resolver.gd")
const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")

var id_factory: IdFactory
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var turn_limit_scoring_service: TurnLimitScoringService
var _chain_builder = ChainBuilderScript.new()
var _outcome_resolver = OutcomeResolverScript.new()

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func build_system_chain(command_type: String) -> Variant:
	return _chain_builder.build_system_chain(id_factory, command_type)

func terminate_invalid_battle(battle_state: BattleState, invalid_code: String) -> void:
	var resolved_message := String(battle_state.runtime_fault_message) if battle_state != null else ""
	if resolved_message.is_empty():
		resolved_message = "BattleResultService terminate_invalid_battle: battle_id=%s phase=%s invalid_code=%s" % [
			str(battle_state.battle_id),
			str(battle_state.phase),
			invalid_code,
		]
	_report_invalid_termination(
		"BattleResultService terminate_invalid_battle: battle_id=%s phase=%s invalid_code=%s" % [
			str(battle_state.battle_id),
			str(battle_state.phase),
			invalid_code,
		]
	)
	_latch_runtime_fault(battle_state, invalid_code, resolved_message)
	battle_state.battle_result.finished = true
	battle_state.battle_result.winner_side_id = null
	battle_state.battle_result.result_type = "no_winner"
	battle_state.battle_result.reason = invalid_code
	battle_state.phase = BattlePhasesScript.FINISHED
	battle_state.chain_context = build_system_chain(EventTypesScript.SYSTEM_INVALID_BATTLE)
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.SYSTEM_INVALID_BATTLE,
		battle_state,
		{
			"source_instance_id": "system:invalid_battle",
			"invalid_battle_code": invalid_code,
			"payload_summary": "invalid battle: %s" % invalid_code,
		}
	))

func hard_terminate_invalid_state(battle_state: BattleState, invalid_code: String, missing_dependency: String) -> void:
	var resolved_message := String(battle_state.runtime_fault_message) if battle_state != null else ""
	if resolved_message.is_empty():
		resolved_message = "BattleResultService hard_terminate_invalid_state: battle_id=%s phase=%s invalid_code=%s missing_dependency=%s" % [
			str(battle_state.battle_id),
			str(battle_state.phase),
			invalid_code,
			missing_dependency,
		]
	_report_invalid_termination(
		"BattleResultService hard_terminate_invalid_state: battle_id=%s phase=%s invalid_code=%s missing_dependency=%s" % [
			str(battle_state.battle_id),
			str(battle_state.phase),
			invalid_code,
			missing_dependency,
		]
	)
	if battle_state.battle_result == null:
		return
	_latch_runtime_fault(battle_state, invalid_code, resolved_message)
	battle_state.battle_result.finished = true
	battle_state.battle_result.winner_side_id = null
	battle_state.battle_result.result_type = "no_winner"
	battle_state.battle_result.reason = invalid_code
	battle_state.phase = BattlePhasesScript.FINISHED
	if id_factory == null or battle_logger == null or log_event_builder == null:
		battle_state.chain_context = null
		return
	battle_state.chain_context = build_system_chain(EventTypesScript.SYSTEM_INVALID_BATTLE)
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.SYSTEM_INVALID_BATTLE,
		battle_state,
		{
			"source_instance_id": "system:invalid_battle",
			"invalid_battle_code": invalid_code,
			"payload_summary": "invalid battle: %s (missing dependency: %s)" % [invalid_code, missing_dependency],
		}
	))

func resolve_initialization_victory(battle_state: BattleState) -> bool:
	return _outcome_resolver.resolve_initialization_victory(
		_chain_builder,
		id_factory,
		battle_logger,
		log_event_builder,
		battle_state,
	)

func resolve_surrender(battle_state: BattleState, commands: Array) -> bool:
	return _outcome_resolver.resolve_surrender(
		_chain_builder,
		id_factory,
		battle_logger,
		log_event_builder,
		battle_state,
		commands
	)

func resolve_standard_victory(battle_state: BattleState) -> bool:
	return _outcome_resolver.resolve_standard_victory(
		_chain_builder,
		id_factory,
		battle_logger,
		log_event_builder,
		battle_state,
	)

func resolve_turn_limit(battle_state: BattleState) -> void:
	_outcome_resolver.resolve_turn_limit(
		_chain_builder,
		id_factory,
		battle_logger,
		log_event_builder,
		turn_limit_scoring_service,
		battle_state
	)

func _report_invalid_termination(message: String) -> void:
	printerr("INVALID_TERMINATION: %s" % message)

func _latch_runtime_fault(battle_state: BattleState, invalid_code: String, message: String) -> void:
	if battle_state == null:
		return
	battle_state.runtime_fault_code = invalid_code
	battle_state.runtime_fault_message = message
