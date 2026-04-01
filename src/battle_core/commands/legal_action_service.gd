extends RefCounted
class_name LegalActionService

const LegalActionSetScript := preload("res://src/battle_core/contracts/legal_action_set.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var rule_mod_service
var domain_legality_service
var last_error_code: Variant = null
var last_error_message: String = ""

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
    if domain_legality_service.last_invalid_battle_code != null:
        return _fail_invalid_state("LegalActionService detected invalid active field runtime while resolving domain legality")
    for skill_id in actor.regular_skill_ids:
        var skill_definition = content_index.skills.get(skill_id)
        if skill_definition == null:
            continue
        var blocked_by_side_domain: bool = side_domain_recast_blocked and content_index.is_domain_skill(skill_id)
        var can_pay_mp: bool = actor.current_mp >= skill_definition.mp_cost
        var allowed_by_rule_mod: bool = _is_action_legal_with_rule_mod(
            battle_state,
            actor.unit_instance_id,
            CommandTypesScript.SKILL,
            skill_id
        )
        if can_pay_mp and allowed_by_rule_mod and not blocked_by_side_domain:
            legal_action_set.legal_skill_ids.append(skill_id)
            has_any_skill_or_ultimate_option = true
            continue
        if blocked_by_side_domain or not allowed_by_rule_mod:
            has_non_mp_blocked_option = true
    if not unit_definition.ultimate_skill_id.is_empty():
        var ultimate_definition = content_index.skills.get(unit_definition.ultimate_skill_id)
        if ultimate_definition != null:
            var blocked_ultimate_by_side_domain: bool = side_domain_recast_blocked and content_index.is_domain_skill(unit_definition.ultimate_skill_id)
            var can_pay_ultimate_mp: bool = actor.current_mp >= ultimate_definition.mp_cost
            var has_ultimate_points: bool = actor.ultimate_points >= actor.ultimate_points_required
            var ultimate_allowed_by_rule_mod: bool = _is_action_legal_with_rule_mod(
                battle_state,
                actor.unit_instance_id,
                CommandTypesScript.ULTIMATE,
                unit_definition.ultimate_skill_id
            )
            if can_pay_ultimate_mp and has_ultimate_points and ultimate_allowed_by_rule_mod and not blocked_ultimate_by_side_domain:
                has_any_skill_or_ultimate_option = true
                legal_action_set.legal_ultimate_ids.append(unit_definition.ultimate_skill_id)
            elif blocked_ultimate_by_side_domain or not ultimate_allowed_by_rule_mod:
                has_non_mp_blocked_option = true
    var switch_allowed_by_rule_mod: bool = _is_action_legal_with_rule_mod(
        battle_state,
        actor.unit_instance_id,
        CommandTypesScript.SWITCH
    )
    for bench_unit_id in side_state.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null and bench_unit.current_hp > 0:
            if switch_allowed_by_rule_mod:
                legal_action_set.legal_switch_target_public_ids.append(bench_unit.public_id)
            else:
                has_non_mp_blocked_option = true
    var has_legal_switch: bool = not legal_action_set.legal_switch_target_public_ids.is_empty()
    var has_any_legal_manual_option: bool = has_any_skill_or_ultimate_option or has_legal_switch
    legal_action_set.wait_allowed = has_any_legal_manual_option or has_non_mp_blocked_option
    if not legal_action_set.wait_allowed \
    and legal_action_set.legal_skill_ids.is_empty() \
    and legal_action_set.legal_switch_target_public_ids.is_empty() \
    and legal_action_set.legal_ultimate_ids.is_empty():
        legal_action_set.forced_command_type = CommandTypesScript.RESOURCE_FORCED_DEFAULT
    return legal_action_set

func _is_action_legal_with_rule_mod(battle_state, actor_id: String, action_type: String, skill_id: String = "") -> bool:
    if rule_mod_service == null:
        _fail_invalid_state("LegalActionService.rule_mod_service is required")
        return false
    return rule_mod_service.is_action_allowed(battle_state, actor_id, action_type, skill_id)

func _fail_invalid_state(message: String):
    last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
    last_error_message = message
    return null
