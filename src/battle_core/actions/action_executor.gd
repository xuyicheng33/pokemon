extends RefCounted
class_name ActionExecutor

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const ActionResultScript := preload("res://src/battle_core/contracts/action_result.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const ActionDomainGuardScript := preload("res://src/battle_core/actions/action_domain_guard.gd")

var action_cast_service
var switch_action_service
var action_log_service
var rule_mod_service
var domain_legality_service
var _domain_guard = ActionDomainGuardScript.new()

func resolve_missing_dependency() -> String:
    if action_cast_service == null:
        return "action_cast_service"
    var cast_missing := str(action_cast_service.resolve_missing_dependency())
    if not cast_missing.is_empty():
        return "action_cast_service.%s" % cast_missing
    if switch_action_service == null:
        return "switch_action_service"
    var switch_missing := str(switch_action_service.resolve_missing_dependency())
    if not switch_missing.is_empty():
        return "switch_action_service.%s" % switch_missing
    if action_log_service == null:
        return "action_log_service"
    var log_missing := str(action_log_service.resolve_missing_dependency())
    if not log_missing.is_empty():
        return "action_log_service.%s" % log_missing
    if rule_mod_service == null:
        return "rule_mod_service"
    if domain_legality_service == null:
        return "domain_legality_service"
    _domain_guard.rule_mod_service = rule_mod_service
    _domain_guard.domain_legality_service = domain_legality_service
    var domain_missing := _domain_guard.resolve_missing_dependency()
    if not domain_missing.is_empty():
        return "domain_guard.%s" % domain_missing
    return ""

func execute_action(queued_action, battle_state, content_index):
    var result = ActionResultScript.new()
    result.action_id = queued_action.action_id
    var command = queued_action.command
    var actor = battle_state.get_unit(command.actor_id)
    var skill_definition = _resolve_skill_definition(command, content_index)
    battle_state.chain_context = _build_chain_context(queued_action, battle_state)
    if not _can_start_and_stay_legal(queued_action, command, actor, battle_state, content_index):
        _log_cancelled_pre_start(queued_action, battle_state, command, result)
        return result
    var action_cast_event_id: String = _apply_action_start_phase(queued_action, battle_state, actor, command, skill_definition, result)
    if result.result_type == "resolved":
        return result
    _dispatch_effects_for_trigger("on_cast", skill_definition, queued_action, actor, battle_state, content_index, result)
    if result.invalid_battle_code != null:
        return result
    if command.command_type == CommandTypesScript.SWITCH:
        var switch_result = switch_action_service.execute_switch_action(queued_action, battle_state, content_index)
        switch_result.action_id = queued_action.action_id
        return switch_result
    var resolved_target = action_cast_service.resolve_target(queued_action, battle_state)
    if resolved_target != null and queued_action.target_snapshot.target_kind != ContentSchemaScript.TARGET_FIELD:
        battle_state.chain_context.target_unit_id = resolved_target.unit_instance_id
    if not action_cast_service.is_action_target_valid(command, queued_action, resolved_target):
        action_log_service.log_action_failed_post_start(queued_action, battle_state, command)
        result.result_type = "action_failed_post_start"
        return result
    var hit_info: Dictionary = action_cast_service.resolve_hit(command, skill_definition, resolved_target, battle_state, content_index)
    if not hit_info["hit"]:
        action_log_service.log_action_miss(
            queued_action,
            battle_state,
            command,
            action_cast_service.resolve_target_instance_id(queued_action, resolved_target),
            hit_info["hit_roll"]
        )
        _dispatch_effects_for_trigger("on_miss", skill_definition, queued_action, actor, battle_state, content_index, result)
        if result.invalid_battle_code != null:
            return result
        result.result_type = "miss"
        return result
    var action_hit_cause_event_id: String = action_log_service.log_action_hit(
        queued_action,
        battle_state,
        command,
        action_cast_service.resolve_target_instance_id(queued_action, resolved_target),
        hit_info["hit_roll"]
    )
    if action_cast_service.is_damage_action(command, skill_definition):
        action_cast_service.apply_direct_damage(queued_action, actor, resolved_target, skill_definition, battle_state, action_hit_cause_event_id)
    if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT:
        action_cast_service.apply_default_recoil(queued_action, actor, battle_state, action_hit_cause_event_id)
    _dispatch_effects_for_trigger("on_hit", skill_definition, queued_action, actor, battle_state, content_index, result)
    if result.invalid_battle_code != null:
        return result
    result.result_type = "resolved"
    return result

func _resolve_skill_definition(command, content_index):
    if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
        return null
    var skill_definition = content_index.skills.get(command.skill_id)
    assert(skill_definition != null, "Missing skill definition: %s" % command.skill_id)
    return skill_definition

func _can_start_and_stay_legal(queued_action, command, actor, battle_state, content_index) -> bool:
    if not _can_start_action(actor, command, battle_state):
        return false
    _domain_guard.rule_mod_service = rule_mod_service
    _domain_guard.domain_legality_service = domain_legality_service
    return _domain_guard.is_action_still_allowed(queued_action, command, actor, battle_state, content_index)

func _log_cancelled_pre_start(queued_action, battle_state, command, result) -> void:
    action_log_service.log_action_cancelled_pre_start(queued_action, battle_state, command)
    result.result_type = "cancelled_pre_start"

func _apply_action_start_phase(queued_action, battle_state, actor, command, skill_definition, result) -> String:
    actor.action_window_passed = true
    actor.has_acted = true
    var consumed_mp: int = action_cast_service.resolve_mp_cost(command, skill_definition)
    var mp_changes: Array = action_cast_service.consume_mp(actor, consumed_mp)
    var action_cast_event_id: String = action_log_service.log_action_cast(queued_action, battle_state, command, mp_changes)
    _apply_action_start_resource_changes(queued_action, battle_state, actor, command, action_cast_event_id)
    result.consumed_mp = consumed_mp
    if command.command_type == CommandTypesScript.WAIT:
        result.result_type = "resolved"
    return action_cast_event_id

func _dispatch_effects_for_trigger(trigger_name: String, skill_definition, queued_action, actor, battle_state, content_index, result) -> void:
    var effect_ids: PackedStringArray = PackedStringArray()
    if skill_definition != null:
        match trigger_name:
            "on_cast":
                effect_ids = skill_definition.effects_on_cast_ids
            "on_miss":
                effect_ids = skill_definition.effects_on_miss_ids
            "on_hit":
                effect_ids = skill_definition.effects_on_hit_ids
    action_cast_service.dispatch_skill_effects(
        effect_ids,
        trigger_name,
        queued_action,
        actor,
        battle_state,
        content_index,
        result
    )

func _build_chain_context(queued_action, battle_state):
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = queued_action.action_id
    chain_context.root_action_id = queued_action.action_id
    chain_context.chain_origin = "action"
    chain_context.action_queue_index = queued_action.queue_index
    chain_context.actor_id = queued_action.command.actor_id
    chain_context.command_type = queued_action.command.command_type
    chain_context.command_source = queued_action.command.command_source
    chain_context.skill_id = queued_action.command.skill_id if queued_action.command.command_type == CommandTypesScript.SKILL or queued_action.command.command_type == CommandTypesScript.ULTIMATE else null
    chain_context.select_timeout = queued_action.command.command_source == "timeout_auto"
    chain_context.select_deadline_ms = battle_state.selection_deadline_ms
    chain_context.target_unit_id = queued_action.target_snapshot.target_unit_id
    chain_context.target_slot = queued_action.target_snapshot.target_slot
    return chain_context

func _can_start_action(actor, command, battle_state) -> bool:
    if actor == null or actor.current_hp <= 0 or actor.leave_state != LeaveStatesScript.ACTIVE:
        return false
    var side_state = battle_state.get_side(command.side_id)
    return side_state != null and side_state.get_active_unit() != null and side_state.get_active_unit().unit_instance_id == actor.unit_instance_id

func _apply_action_start_resource_changes(queued_action, battle_state, actor, command, cause_event_id: String) -> void:
    if actor == null:
        return
    match command.command_type:
        CommandTypesScript.SKILL:
            _gain_ultimate_points(queued_action, battle_state, actor, cause_event_id)
        CommandTypesScript.ULTIMATE:
            _clear_ultimate_points(queued_action, battle_state, actor, cause_event_id)

func _gain_ultimate_points(queued_action, battle_state, actor, cause_event_id: String) -> void:
    if actor.ultimate_points_cap <= 0 or actor.ultimate_point_gain_on_regular_skill_cast <= 0:
        return
    var before_points: int = actor.ultimate_points
    actor.ultimate_points = min(actor.ultimate_points_cap, actor.ultimate_points + actor.ultimate_point_gain_on_regular_skill_cast)
    action_log_service.log_action_resource_change(
        queued_action,
        battle_state,
        actor,
        "ultimate_points",
        before_points,
        actor.ultimate_points,
        cause_event_id,
        "%s ultimate_points %+d (%d/%d)" % [actor.public_id, actor.ultimate_points - before_points, actor.ultimate_points, actor.ultimate_points_cap]
    )

func _clear_ultimate_points(queued_action, battle_state, actor, cause_event_id: String) -> void:
    var before_points: int = actor.ultimate_points
    actor.ultimate_points = 0
    action_log_service.log_action_resource_change(
        queued_action,
        battle_state,
        actor,
        "ultimate_points",
        before_points,
        actor.ultimate_points,
        cause_event_id,
        "%s ultimate_points reset (%d/%d)" % [actor.public_id, actor.ultimate_points, actor.ultimate_points_cap]
    )
