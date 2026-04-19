extends RefCounted
class_name ActionExecutor

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")
const ActionChainContextBuilderScript := preload("res://src/battle_core/actions/action_chain_context_builder.gd")
const ActionStartPhaseServiceScript := preload("res://src/battle_core/actions/action_start_phase_service.gd")
const ActionSkillEffectServiceScript := preload("res://src/battle_core/actions/action_skill_effect_service.gd")
const ActionExecutionResolutionServiceScript := preload("res://src/battle_core/actions/action_execution_resolution_service.gd")
const ActionDomainGuardScript := preload("res://src/battle_core/actions/action_domain_guard.gd")
const SwitchActionServiceScript := preload("res://src/battle_core/actions/switch_action_service.gd")

const COMPOSE_DEPS := [
	{"field": "action_log_service", "source": "action_log_service", "nested": true},
	{"field": "action_cast_service", "source": "action_cast_service", "nested": true},
	{"field": "rule_mod_service", "source": "rule_mod_service"},
	{"field": "domain_legality_service", "source": "domain_legality_service"},
	{"field": "replacement_service", "source": "replacement_service"},
]

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const ActionResultScript := preload("res://src/battle_core/contracts/action_result.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var action_log_service: ActionLogService
var action_cast_service: ActionCastService
var rule_mod_service: RuleModService
var domain_legality_service: DomainLegalityService
var replacement_service: ReplacementService

var action_chain_context_builder: ActionChainContextBuilder
var action_start_phase_service: ActionStartPhaseService
var action_skill_effect_service: ActionSkillEffectService
var action_execution_resolution_service: ActionExecutionResolutionService
var switch_action_service: SwitchActionService
var action_domain_guard: ActionDomainGuard

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func _compose_post_wire() -> void:
	action_chain_context_builder = ActionChainContextBuilderScript.new()
	action_start_phase_service = ActionStartPhaseServiceScript.new()
	action_start_phase_service.action_cast_service = action_cast_service
	action_start_phase_service.action_log_service = action_log_service
	action_skill_effect_service = ActionSkillEffectServiceScript.new()
	action_skill_effect_service.action_cast_service = action_cast_service
	action_execution_resolution_service = ActionExecutionResolutionServiceScript.new()
	action_execution_resolution_service.action_cast_service = action_cast_service
	action_execution_resolution_service.action_log_service = action_log_service
	action_execution_resolution_service.action_skill_effect_service = action_skill_effect_service
	action_domain_guard = ActionDomainGuardScript.new()
	action_domain_guard.rule_mod_service = rule_mod_service
	action_domain_guard.domain_legality_service = domain_legality_service
	switch_action_service = SwitchActionServiceScript.new()
	switch_action_service.action_cast_service = action_cast_service
	switch_action_service.action_log_service = action_log_service
	switch_action_service.replacement_service = replacement_service


func execute_action(queued_action: QueuedAction, battle_state: BattleState, content_index: BattleContentIndex) -> Variant:
	var result = ActionResultScript.new()
	result.action_id = queued_action.action_id
	var command = queued_action.command
	var actor = battle_state.get_unit(command.actor_id)
	var skill_definition = _resolve_skill_definition(command, content_index)
	battle_state.chain_context = action_chain_context_builder.build_chain_context(queued_action, battle_state, skill_definition)
	if _uses_skill_definition(command.command_type):
		if skill_definition == null:
			result.invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
			return result
	if not _can_start_and_stay_legal(queued_action, command, actor, battle_state, content_index):
		_log_cancelled_pre_start(queued_action, battle_state, command, result)
		return result
	var start_phase: Dictionary = action_start_phase_service.apply_action_start_phase(
		queued_action,
		battle_state,
		actor,
		command,
		skill_definition
	)
	result.consumed_mp = int(start_phase["consumed_mp"])
	if start_phase["result_type"] != null:
		result.result_type = str(start_phase["result_type"])
		return result
	action_skill_effect_service.dispatch_trigger("on_cast", skill_definition, queued_action, actor, battle_state, content_index, result)
	if result.invalid_battle_code != null:
		return result
	if command.command_type == CommandTypesScript.SWITCH:
		var switch_result = switch_action_service.execute_switch_action(queued_action, battle_state, content_index)
		switch_result.action_id = queued_action.action_id
		return switch_result
	action_execution_resolution_service.resolve_started_action(
		queued_action,
		actor,
		command,
		skill_definition,
		battle_state,
		content_index,
		result
	)
	return result

func _resolve_skill_definition(command: Command, content_index: BattleContentIndex) -> Variant:
	if not _uses_skill_definition(command.command_type):
		return null
	return content_index.skills.get(command.skill_id, null)

func _uses_skill_definition(command_type: String) -> bool:
	return command_type == CommandTypesScript.SKILL or command_type == CommandTypesScript.ULTIMATE

func _can_start_and_stay_legal(queued_action: QueuedAction, command: Command, actor, battle_state: BattleState, content_index: BattleContentIndex) -> bool:
	if not _can_start_action(actor, command, battle_state):
		return false
	return action_domain_guard.is_action_still_allowed(queued_action, command, actor, battle_state, content_index)

func _log_cancelled_pre_start(queued_action: QueuedAction, battle_state: BattleState, command: Command, result) -> void:
	action_log_service.log_action_cancelled_pre_start(queued_action, battle_state, command)
	result.result_type = "cancelled_pre_start"

func _can_start_action(actor, command: Command, battle_state: BattleState) -> bool:
	if actor == null or actor.current_hp <= 0 or actor.leave_state != LeaveStatesScript.ACTIVE:
		return false
	var side_state = battle_state.get_side(command.side_id)
	return side_state != null and side_state.get_active_unit() != null and side_state.get_active_unit().unit_instance_id == actor.unit_instance_id
