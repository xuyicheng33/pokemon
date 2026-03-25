extends RefCounted
class_name LegalActionService

const LegalActionSetScript := preload("res://src/battle_core/contracts/legal_action_set.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

var rule_mod_service

func get_legal_actions(battle_state, side_id: String, content_index):
    var side_state = battle_state.get_side(side_id)
    assert(side_state != null, "Unknown side: %s" % side_id)
    var actor = side_state.get_active_unit()
    assert(actor != null, "Side %s has no active unit" % side_id)
    var unit_definition = content_index.units.get(actor.definition_id)
    assert(unit_definition != null, "Missing unit definition: %s" % actor.definition_id)
    var legal_action_set = LegalActionSetScript.new()
    legal_action_set.actor_id = actor.unit_instance_id
    for skill_id in unit_definition.skill_ids:
        var skill_definition = content_index.skills.get(skill_id)
        if skill_definition != null \
        and actor.current_mp >= skill_definition.mp_cost \
        and _is_skill_legal_with_rule_mod(battle_state, actor.unit_instance_id, skill_id):
            legal_action_set.legal_skill_ids.append(skill_id)
    if not unit_definition.ultimate_skill_id.is_empty():
        var ultimate_definition = content_index.skills.get(unit_definition.ultimate_skill_id)
        if ultimate_definition != null \
        and actor.current_mp >= ultimate_definition.mp_cost \
        and _is_skill_legal_with_rule_mod(battle_state, actor.unit_instance_id, unit_definition.ultimate_skill_id):
            legal_action_set.legal_ultimate_ids.append(unit_definition.ultimate_skill_id)
    for bench_unit_id in side_state.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null and bench_unit.current_hp > 0:
            legal_action_set.legal_switch_target_ids.append(bench_unit_id)
    if legal_action_set.legal_skill_ids.is_empty() \
    and legal_action_set.legal_switch_target_ids.is_empty() \
    and legal_action_set.legal_ultimate_ids.is_empty():
        legal_action_set.forced_command_type = CommandTypesScript.RESOURCE_FORCED_DEFAULT
    return legal_action_set

func _is_skill_legal_with_rule_mod(battle_state, actor_id: String, skill_id: String) -> bool:
    if rule_mod_service == null:
        return true
    return rule_mod_service.is_skill_allowed(battle_state, actor_id, skill_id)
