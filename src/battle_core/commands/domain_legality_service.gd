extends RefCounted
class_name DomainLegalityService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var domain_clash_orchestrator
var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
    return last_invalid_battle_code

func resolve_missing_dependency() -> String:
    if domain_clash_orchestrator == null:
        return "domain_clash_orchestrator"
    var missing := str(domain_clash_orchestrator.resolve_missing_dependency())
    if not missing.is_empty():
        return "domain_clash_orchestrator.%s" % missing
    return ""

func is_domain_command(command, content_index) -> bool:
    last_invalid_battle_code = null
    if domain_clash_orchestrator == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
        return false
    var result: bool = domain_clash_orchestrator.is_domain_command(command, content_index)
    last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
    return result

func resolve_active_domain_creator_side_id(battle_state, content_index) -> String:
    last_invalid_battle_code = null
    if domain_clash_orchestrator == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
        return ""
    var creator_side_id: String = domain_clash_orchestrator.resolve_active_domain_creator_side_id(battle_state, content_index)
    last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
    return creator_side_id

func is_side_domain_recast_blocked(battle_state, side_id: String, content_index) -> bool:
    if domain_clash_orchestrator == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
        return false
    var blocked: bool = domain_clash_orchestrator.is_side_domain_recast_blocked(battle_state, side_id, content_index)
    last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
    return blocked

func is_domain_command_blocked_by_active_side_domain(command, battle_state, content_index) -> bool:
    if domain_clash_orchestrator == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
        return false
    var blocked: bool = domain_clash_orchestrator.is_domain_command_blocked_by_active_side_domain(command, battle_state, content_index)
    last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
    return blocked

func can_bypass_domain_recast_for_clash(queued_action, command, battle_state, content_index) -> bool:
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
