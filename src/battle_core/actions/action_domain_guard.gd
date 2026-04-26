extends RefCounted
class_name ActionDomainGuard

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

var rule_mod_service: RuleModService
var domain_legality_service: DomainLegalityService


func is_action_still_allowed_result(queued_action: QueuedAction, command: Command, actor, battle_state: BattleState, content_index: BattleContentIndex) -> Dictionary:
	if actor == null:
		return _result(false)
	if domain_legality_service.is_domain_command_blocked_by_active_side_domain(command, battle_state, content_index):
		var domain_error = domain_legality_service.invalid_battle_code()
		return _result(false, domain_error)
	var domain_block_error = domain_legality_service.invalid_battle_code()
	if domain_block_error != null:
		return _result(false, domain_block_error)
	match command.command_type:
		CommandTypesScript.SKILL:
			if domain_legality_service.can_bypass_domain_recast_for_clash(queued_action, command, battle_state, content_index):
				var bypass_error = domain_legality_service.invalid_battle_code()
				return _result(bypass_error == null, bypass_error)
			return _rule_mod_result(rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, CommandTypesScript.SKILL, command.skill_id))
		CommandTypesScript.ULTIMATE:
			if domain_legality_service.can_bypass_domain_recast_for_clash(queued_action, command, battle_state, content_index):
				var bypass_error = domain_legality_service.invalid_battle_code()
				return _result(bypass_error == null, bypass_error)
			return _rule_mod_result(rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, CommandTypesScript.ULTIMATE, command.skill_id))
		CommandTypesScript.SWITCH:
			return _rule_mod_result(rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, CommandTypesScript.SWITCH))
		_:
			return _result(true)

func is_action_still_allowed(queued_action: QueuedAction, command: Command, actor, battle_state: BattleState, content_index: BattleContentIndex) -> bool:
	return bool(is_action_still_allowed_result(queued_action, command, actor, battle_state, content_index).get("allowed", false))

func _rule_mod_result(allowed: bool) -> Dictionary:
	var rule_error: Dictionary = rule_mod_service.error_state()
	return _result(allowed, rule_error.get("code", null))

func _result(allowed: bool, invalid_battle_code = null) -> Dictionary:
	return {"allowed": allowed, "invalid_battle_code": invalid_battle_code}
