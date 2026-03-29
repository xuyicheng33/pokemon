extends RefCounted
class_name ActionDomainGuard

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

var rule_mod_service

func resolve_missing_dependency() -> String:
    if rule_mod_service == null:
        return "rule_mod_service"
    return ""

func is_action_still_allowed(queued_action, command, actor, battle_state, content_index) -> bool:
    if actor == null:
        return false
    if _is_blocked_by_active_side_domain(command, battle_state, content_index):
        return false
    match command.command_type:
        CommandTypesScript.SKILL:
            if _can_bypass_legality_for_domain_clash(queued_action, command, battle_state, content_index):
                return true
            return rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, CommandTypesScript.SKILL, command.skill_id)
        CommandTypesScript.ULTIMATE:
            if _can_bypass_legality_for_domain_clash(queued_action, command, battle_state, content_index):
                return true
            return rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, CommandTypesScript.ULTIMATE, command.skill_id)
        CommandTypesScript.SWITCH:
            return rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, CommandTypesScript.SWITCH)
        _:
            return true

func _is_blocked_by_active_side_domain(command, battle_state, content_index) -> bool:
    if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
        return false
    if not content_index.is_domain_skill(command.skill_id):
        return false
    var creator_side_id := _get_active_domain_creator_side_id(battle_state, content_index)
    if creator_side_id.is_empty():
        return false
    return creator_side_id == String(command.side_id)

func _can_bypass_legality_for_domain_clash(queued_action, command, battle_state, content_index) -> bool:
    if not bool(queued_action.domain_clash_protected):
        return false
    if not content_index.is_domain_skill(command.skill_id):
        return false
    var creator_side_id := _get_active_domain_creator_side_id(battle_state, content_index)
    if creator_side_id.is_empty():
        return false
    return creator_side_id != String(command.side_id)

func _get_active_domain_creator_side_id(battle_state, content_index) -> String:
    if battle_state.field_state == null:
        return ""
    var active_field_definition = content_index.fields.get(battle_state.field_state.field_def_id)
    if active_field_definition == null or String(active_field_definition.field_kind) != ContentSchemaScript.FIELD_KIND_DOMAIN:
        return ""
    var creator_side = battle_state.get_side_for_unit(String(battle_state.field_state.creator))
    if creator_side == null:
        return ""
    return String(creator_side.side_id)
