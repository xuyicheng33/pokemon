extends RefCounted
class_name DomainLegalityService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "domain_clash_orchestrator",
		"source": "domain_clash_orchestrator",
		"nested": true,
	},
]

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var domain_clash_orchestrator
var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)


func is_domain_command(command: Command, content_index: BattleContentIndex) -> bool:
	last_invalid_battle_code = null
	if domain_clash_orchestrator == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
		return false
	var result: bool = domain_clash_orchestrator.is_domain_command(command, content_index)
	last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
	return result

func resolve_active_domain_creator_side_id(battle_state: BattleState, content_index: BattleContentIndex) -> String:
	last_invalid_battle_code = null
	if domain_clash_orchestrator == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
		return ""
	var creator_side_id: String = domain_clash_orchestrator.resolve_active_domain_creator_side_id(battle_state, content_index)
	last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
	return creator_side_id

func is_side_domain_recast_blocked(battle_state: BattleState, side_id: String, content_index: BattleContentIndex) -> bool:
	if domain_clash_orchestrator == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
		return false
	var blocked: bool = domain_clash_orchestrator.is_side_domain_recast_blocked(battle_state, side_id, content_index)
	last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
	return blocked

func is_domain_command_blocked_by_active_side_domain(command: Command, battle_state: BattleState, content_index: BattleContentIndex) -> bool:
	if domain_clash_orchestrator == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
		return false
	var blocked: bool = domain_clash_orchestrator.is_domain_command_blocked_by_active_side_domain(command, battle_state, content_index)
	last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
	return blocked

func can_bypass_domain_recast_for_clash(queued_action: QueuedAction, command: Command, battle_state: BattleState, content_index: BattleContentIndex) -> bool:
	if domain_clash_orchestrator == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
		return false
	var bypass: bool = domain_clash_orchestrator.can_bypass_domain_recast_for_clash(
		queued_action,
		command,
		battle_state,
		content_index
	)
	last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
	return bypass
