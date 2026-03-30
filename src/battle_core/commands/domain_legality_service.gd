extends RefCounted
class_name DomainLegalityService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

func is_domain_command(command, content_index) -> bool:
    if command == null:
        return false
    if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
        return false
    if content_index == null:
        return false
    return content_index.is_domain_skill(String(command.skill_id))

func resolve_active_domain_creator_side_id(battle_state, content_index) -> String:
    if battle_state == null or battle_state.field_state == null or content_index == null:
        return ""
    var active_field_definition = content_index.fields.get(String(battle_state.field_state.field_def_id))
    if active_field_definition == null:
        return ""
    if String(active_field_definition.field_kind) != ContentSchemaScript.FIELD_KIND_DOMAIN:
        return ""
    var creator_side = battle_state.get_side_for_unit(String(battle_state.field_state.creator))
    assert(creator_side != null, "DomainLegalityService missing creator side for active domain field %s" % String(battle_state.field_state.field_def_id))
    return String(creator_side.side_id)

func is_side_domain_recast_blocked(battle_state, side_id: String, content_index) -> bool:
    var creator_side_id := resolve_active_domain_creator_side_id(battle_state, content_index)
    if creator_side_id.is_empty():
        return false
    return creator_side_id == side_id

func is_domain_command_blocked_by_active_side_domain(command, battle_state, content_index) -> bool:
    if not is_domain_command(command, content_index):
        return false
    return is_side_domain_recast_blocked(battle_state, String(command.side_id), content_index)

func can_bypass_domain_recast_for_clash(queued_action, command, battle_state, content_index) -> bool:
    if queued_action == null or not bool(queued_action.domain_clash_protected):
        return false
    if not is_domain_command(command, content_index):
        return false
    var creator_side_id := resolve_active_domain_creator_side_id(battle_state, content_index)
    if creator_side_id.is_empty():
        return false
    return creator_side_id != String(command.side_id)
