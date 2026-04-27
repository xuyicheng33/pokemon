extends RefCounted
class_name BattleResultService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")

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

var id_factory: IdFactory
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var turn_limit_scoring_service: TurnLimitScoringService
var _chain_builder = ChainBuilderScript.new()
var _outcome_resolver = OutcomeResolverScript.new()

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)


func build_system_chain(command_type: String) -> Variant:
	return _chain_builder.build_system_chain(id_factory, command_type)

# 终止流的协调入口在下方 terminate_invalid_battle / hard_terminate_invalid_state /
# resolve_*_victory / resolve_turn_limit。最终落地都走
# `BattleState.finalize_invalid_termination` 与 `BattleState.finalize_normal_termination`
# 两个 setter，它们内部串接 `record_runtime_fault`（仅 invalid 路径）+ battle_result
# 写入 + phase 切到 FINISHED。底层 helper（LogEventBuilder._fail、
# TurnSelectionResolver._fail_invalid_result）直接调用 BattleState 的
# finalize_invalid_termination / record_runtime_fault，避免运行期 compose cycle。

func terminate_invalid_battle(battle_state: BattleState, invalid_code: String) -> void:
	var resolved_message := String(battle_state.runtime_fault_message()) if battle_state != null else ""
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
	battle_state.finalize_invalid_termination(invalid_code, resolved_message)
	battle_state.set_phase_chain_context(build_system_chain(EventTypesScript.SYSTEM_INVALID_BATTLE))
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
	var resolved_message := String(battle_state.runtime_fault_message()) if battle_state != null else ""
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
	battle_state.finalize_invalid_termination(invalid_code, resolved_message)
	if id_factory == null or battle_logger == null or log_event_builder == null:
		battle_state.clear_chain_context_stack()
		return
	battle_state.set_phase_chain_context(build_system_chain(EventTypesScript.SYSTEM_INVALID_BATTLE))
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
