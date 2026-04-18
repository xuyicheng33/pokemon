extends RefCounted
class_name ActionDomainGuard

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "rule_mod_service",
		"source": "rule_mod_service",
		"nested": true,
	},
	{
		"field": "domain_legality_service",
		"source": "domain_legality_service",
		"nested": true,
	},
]

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

var rule_mod_service
var domain_legality_service

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func is_action_still_allowed(queued_action, command, actor, battle_state, content_index) -> bool:
    if actor == null:
        return false
    if domain_legality_service.is_domain_command_blocked_by_active_side_domain(command, battle_state, content_index):
        return false
    match command.command_type:
        CommandTypesScript.SKILL:
            if domain_legality_service.can_bypass_domain_recast_for_clash(queued_action, command, battle_state, content_index):
                return true
            return rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, CommandTypesScript.SKILL, command.skill_id)
        CommandTypesScript.ULTIMATE:
            if domain_legality_service.can_bypass_domain_recast_for_clash(queued_action, command, battle_state, content_index):
                return true
            return rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, CommandTypesScript.ULTIMATE, command.skill_id)
        CommandTypesScript.SWITCH:
            return rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, CommandTypesScript.SWITCH)
        _:
            return true
