extends RefCounted
class_name LegalActionService

const LegalActionSetScript := preload("res://src/battle_core/contracts/legal_action_set.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var rule_mod_service
var domain_legality_service
var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
    return {
        "code": last_error_code,
        "message": last_error_message,
    }

func resolve_missing_dependency() -> String:
    if rule_mod_service == null:
        return "rule_mod_service"
    if domain_legality_service == null:
        return "domain_legality_service"
    return ""

func get_legal_actions(battle_state, side_id: String, content_index):
    last_error_code = null
    last_error_message = ""
    var side_state = battle_state.get_side(side_id)
    if side_state == null:
        return _fail_invalid_state("Unknown side: %s" % side_id)
    var actor = side_state.get_active_unit()
    if actor == null:
        return _fail_invalid_state("Side %s has no active unit" % side_id)
    var unit_definition = content_index.units.get(actor.definition_id)
    if unit_definition == null:
        return _fail_invalid_state("Missing unit definition: %s" % actor.definition_id)
    var legal_action_set = LegalActionSetScript.new()
    legal_action_set.actor_public_id = actor.public_id
    var has_non_mp_blocked_option: bool = false
    var has_any_skill_or_ultimate_option: bool = false
    if domain_legality_service == null:
        return _fail_invalid_state("LegalActionService.domain_legality_service is required")
    var side_domain_recast_blocked: bool = domain_legality_service.is_side_domain_recast_blocked(
        battle_state,
        side_id,
        content_index
    )
    if domain_legality_service.invalid_battle_code() != null:
        return _fail_invalid_state("LegalActionService detected invalid active field runtime while resolving domain legality")
    var cast_flags := _collect_cast_action_flags(
        battle_state,
        actor,
        unit_definition,
        content_index,
        side_domain_recast_blocked,
        legal_action_set
    )
    has_non_mp_blocked_option = bool(cast_flags["has_non_mp_blocked_option"])
    has_any_skill_or_ultimate_option = bool(cast_flags["has_any_skill_or_ultimate_option"])
    var switch_flags := _collect_switch_action_flags(battle_state, side_state, actor, legal_action_set)
    if bool(switch_flags["has_non_mp_blocked_option"]):
        has_non_mp_blocked_option = true
    _finalize_wait_and_forced_default(
        legal_action_set,
        has_any_skill_or_ultimate_option,
        bool(switch_flags["has_legal_switch"]),
        has_non_mp_blocked_option
    )
    return legal_action_set

func _collect_cast_action_flags(
    battle_state,
    actor,
    unit_definition,
    content_index,
    side_domain_recast_blocked: bool,
    legal_action_set
) -> Dictionary:
    var has_non_mp_blocked_option := false
    var has_any_skill_or_ultimate_option := false
    for skill_id in actor.regular_skill_ids:
        var skill_resolution := _resolve_skill_legality(
            battle_state,
            actor,
            skill_id,
            content_index,
            side_domain_recast_blocked
        )
        if bool(skill_resolution["is_legal"]):
            legal_action_set.legal_skill_ids.append(skill_id)
            has_any_skill_or_ultimate_option = true
            continue
        if bool(skill_resolution["blocked_non_mp"]):
            has_non_mp_blocked_option = true
    var ultimate_resolution := _resolve_ultimate_legality(
        battle_state,
        actor,
        unit_definition,
        content_index,
        side_domain_recast_blocked
    )
    if bool(ultimate_resolution["is_legal"]):
        has_any_skill_or_ultimate_option = true
        legal_action_set.legal_ultimate_ids.append(unit_definition.ultimate_skill_id)
    elif bool(ultimate_resolution["blocked_non_mp"]):
        has_non_mp_blocked_option = true
    return {
        "has_non_mp_blocked_option": has_non_mp_blocked_option,
        "has_any_skill_or_ultimate_option": has_any_skill_or_ultimate_option,
    }

func _resolve_skill_legality(battle_state, actor, skill_id: String, content_index, side_domain_recast_blocked: bool) -> Dictionary:
    var skill_definition = content_index.skills.get(skill_id)
    if skill_definition == null:
        return {"is_legal": false, "blocked_non_mp": false}
    var blocked_by_side_domain: bool = side_domain_recast_blocked and content_index.is_domain_skill(skill_id)
    var allowed_by_rule_mod: bool = _is_action_legal_with_rule_mod(
        battle_state,
        actor.unit_instance_id,
        CommandTypesScript.SKILL,
        skill_id
    )
    return {
        "is_legal": actor.current_mp >= skill_definition.mp_cost and allowed_by_rule_mod and not blocked_by_side_domain,
        "blocked_non_mp": blocked_by_side_domain or not allowed_by_rule_mod,
    }

func _resolve_ultimate_legality(battle_state, actor, unit_definition, content_index, side_domain_recast_blocked: bool) -> Dictionary:
    if unit_definition == null or unit_definition.ultimate_skill_id.is_empty():
        return {"is_legal": false, "blocked_non_mp": false}
    var ultimate_definition = content_index.skills.get(unit_definition.ultimate_skill_id)
    if ultimate_definition == null:
        return {"is_legal": false, "blocked_non_mp": false}
    var blocked_by_side_domain: bool = side_domain_recast_blocked and content_index.is_domain_skill(unit_definition.ultimate_skill_id)
    var allowed_by_rule_mod: bool = _is_action_legal_with_rule_mod(
        battle_state,
        actor.unit_instance_id,
        CommandTypesScript.ULTIMATE,
        unit_definition.ultimate_skill_id
    )
    return {
        "is_legal": actor.current_mp >= ultimate_definition.mp_cost \
            and actor.ultimate_points >= actor.ultimate_points_required \
            and allowed_by_rule_mod \
            and not blocked_by_side_domain,
        "blocked_non_mp": blocked_by_side_domain or not allowed_by_rule_mod,
    }

func _collect_switch_action_flags(battle_state, side_state, actor, legal_action_set) -> Dictionary:
    var switch_allowed_by_rule_mod: bool = _is_action_legal_with_rule_mod(
        battle_state,
        actor.unit_instance_id,
        CommandTypesScript.SWITCH
    )
    for bench_unit_id in side_state.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null and bench_unit.current_hp > 0 and switch_allowed_by_rule_mod:
            legal_action_set.legal_switch_target_public_ids.append(bench_unit.public_id)
    return {
        "has_legal_switch": not legal_action_set.legal_switch_target_public_ids.is_empty(),
        "has_non_mp_blocked_option": not switch_allowed_by_rule_mod and _has_alive_bench_unit(battle_state, side_state),
    }

func _has_alive_bench_unit(battle_state, side_state) -> bool:
    for bench_unit_id in side_state.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null and bench_unit.current_hp > 0:
            return true
    return false

func _finalize_wait_and_forced_default(
    legal_action_set,
    has_any_skill_or_ultimate_option: bool,
    has_legal_switch: bool,
    has_non_mp_blocked_option: bool
) -> void:
    var has_any_legal_manual_option: bool = has_any_skill_or_ultimate_option or has_legal_switch
    legal_action_set.wait_allowed = has_any_legal_manual_option or has_non_mp_blocked_option
    if not legal_action_set.wait_allowed \
    and legal_action_set.legal_skill_ids.is_empty() \
    and legal_action_set.legal_switch_target_public_ids.is_empty() \
    and legal_action_set.legal_ultimate_ids.is_empty():
        legal_action_set.forced_command_type = CommandTypesScript.RESOURCE_FORCED_DEFAULT

func _is_action_legal_with_rule_mod(battle_state, actor_id: String, action_type: String, skill_id: String = "") -> bool:
    if rule_mod_service == null:
        _fail_invalid_state("LegalActionService.rule_mod_service is required")
        return false
    return rule_mod_service.is_action_allowed(battle_state, actor_id, action_type, skill_id)

func _fail_invalid_state(message: String):
    last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
    last_error_message = message
    return null
