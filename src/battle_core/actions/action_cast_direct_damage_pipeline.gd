extends RefCounted
class_name ActionCastDirectDamagePipeline

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ActionCastExecuteContractHelperScript := preload("res://src/battle_core/actions/action_cast_execute_contract_helper.gd")
const ActionCastDamageSegmentHelperScript := preload("res://src/battle_core/actions/action_cast_damage_segment_helper.gd")
var damage_service
var combat_type_service
var stat_calculator
var rule_mod_service
var faint_killer_attribution_service
var action_log_service
var power_bonus_resolver
var trigger_batch_runner

func resolve_missing_dependency() -> String:
    if damage_service == null:
        return "damage_service"
    if combat_type_service == null:
        return "combat_type_service"
    if stat_calculator == null:
        return "stat_calculator"
    if rule_mod_service == null:
        return "rule_mod_service"
    if faint_killer_attribution_service == null:
        return "faint_killer_attribution_service"
    if action_log_service == null:
        return "action_log_service"
    if power_bonus_resolver == null:
        return "power_bonus_resolver"
    if trigger_batch_runner == null:
        return "trigger_batch_runner"
    return ""

func apply_direct_damage(queued_action, actor, target, skill_definition, battle_state, content_index, cause_event_id: String, source_kind_order_active_skill: int) -> Dictionary:
    if target == null:
        return {"invalid_battle_code": null, "resolved_segments": 0}
    if ActionCastExecuteContractHelperScript.should_execute_skill(actor, target, skill_definition):
        _apply_execute_damage(
            queued_action,
            actor,
            target,
            battle_state,
            cause_event_id,
            source_kind_order_active_skill
        )
        return {"invalid_battle_code": null, "resolved_segments": 0}
    var final_multiplier: float = rule_mod_service.get_final_multiplier(battle_state, actor.unit_instance_id)
    var damage_segments: Array = ActionCastDamageSegmentHelperScript.resolve_damage_segments(
        skill_definition,
        actor,
        target,
        power_bonus_resolver
    )
    var total_segments := damage_segments.size()
    var resolved_segments := 0
    for segment_index in range(total_segments):
        if not ActionCastDamageSegmentHelperScript.can_continue_damage_sequence(target):
            break
        var damage_segment: Dictionary = damage_segments[segment_index]
        var damage_context := ActionCastDamageSegmentHelperScript.build_direct_damage_context(
            actor,
            target,
            int(damage_segment.get("power", 0)),
            String(damage_segment.get("damage_kind", ContentSchemaScript.DAMAGE_KIND_PHYSICAL)),
            stat_calculator
        )
        var segment_combat_type_id := String(damage_segment.get("combat_type_id", ""))
        var incoming_action_multiplier: float = 1.0
        if queued_action != null and queued_action.command != null:
            incoming_action_multiplier = rule_mod_service.resolve_incoming_action_final_multiplier(
                battle_state,
                target.unit_instance_id,
                String(queued_action.command.command_type),
                segment_combat_type_id
            )
        var type_effectiveness: float = combat_type_service.calc_effectiveness(
            segment_combat_type_id,
            ActionCastDamageSegmentHelperScript.resolve_unit_combat_types(target)
        )
        var damage_amount: int = damage_service.apply_final_mod(
            damage_service.calc_base_damage(
                battle_state.battle_level,
                int(damage_context.power),
                int(damage_context.attack_value),
                int(damage_context.defense_value)
            ),
            final_multiplier * incoming_action_multiplier * type_effectiveness
        )
        var before_hp: int = target.current_hp
        target.current_hp = clamp(target.current_hp - damage_amount, 0, target.max_hp)
        var value_change = action_log_service.build_value_change(target.unit_instance_id, "hp", before_hp, target.current_hp)
        var log_event = action_log_service.log_damage(
            queued_action,
            battle_state,
            actor,
            target,
            damage_amount,
            value_change,
            type_effectiveness,
            cause_event_id,
            segment_index + 1,
            total_segments
        )
        _record_fatal_damage(
            battle_state,
            target.unit_instance_id,
            before_hp,
            target.current_hp,
            actor.unit_instance_id,
            queued_action.action_id,
            queued_action.priority,
            queued_action.speed_snapshot,
            log_event.event_step_id,
            source_kind_order_active_skill
        )
        resolved_segments += 1
        var segment_invalid_code = _dispatch_receive_damage_segment_trigger(
            queued_action,
            battle_state,
            content_index,
            target.unit_instance_id,
            segment_index + 1,
            total_segments,
            segment_combat_type_id
        )
        if segment_invalid_code != null:
            return {
                "invalid_battle_code": segment_invalid_code,
                "resolved_segments": resolved_segments,
            }
    return {
        "invalid_battle_code": null,
        "resolved_segments": resolved_segments,
    }

func apply_default_recoil(queued_action, actor, battle_state, cause_event_id: String, source_kind_order_active_skill: int) -> void:
    var recoil_ratio: float = 0.25
    if battle_state != null:
        recoil_ratio = float(battle_state.default_recoil_ratio)
    var recoil_amount: int = max(1, int(floor(float(actor.max_hp) * recoil_ratio)))
    var before_hp: int = actor.current_hp
    actor.current_hp = clamp(actor.current_hp - recoil_amount, 0, actor.max_hp)
    var value_change = action_log_service.build_value_change(actor.unit_instance_id, "hp", before_hp, actor.current_hp)
    var log_event = action_log_service.log_recoil(queued_action, battle_state, actor, recoil_amount, value_change, cause_event_id)
    _record_fatal_damage(
        battle_state,
        actor.unit_instance_id,
        before_hp,
        actor.current_hp,
        actor.unit_instance_id,
        queued_action.action_id,
        queued_action.priority,
        queued_action.speed_snapshot,
        log_event.event_step_id,
        source_kind_order_active_skill
    )

func _apply_execute_damage(queued_action, actor, target, battle_state, cause_event_id: String, source_kind_order_active_skill: int) -> void:
    var before_hp: int = target.current_hp
    target.current_hp = 0
    var value_change = action_log_service.build_value_change(target.unit_instance_id, "hp", before_hp, target.current_hp)
    var log_event = action_log_service.log_damage(
        queued_action,
        battle_state,
        actor,
        target,
        before_hp,
        value_change,
        1.0,
        cause_event_id,
        0,
        0,
        "[execute]"
    )
    _record_fatal_damage(
        battle_state,
        target.unit_instance_id,
        before_hp,
        target.current_hp,
        actor.unit_instance_id,
        queued_action.action_id,
        queued_action.priority,
        queued_action.speed_snapshot,
        log_event.event_step_id,
        source_kind_order_active_skill
    )

func _record_fatal_damage(battle_state, target_unit_id: String, before_hp: int, after_hp: int, killer_unit_id: Variant, source_instance_id: String, priority: int, source_order_speed_snapshot: int, cause_event_step_id: int, source_kind_order_active_skill: int) -> void:
    if faint_killer_attribution_service == null:
        return
    faint_killer_attribution_service.record_fatal_damage(
        battle_state,
        target_unit_id,
        before_hp,
        after_hp,
        killer_unit_id,
        source_instance_id,
        source_kind_order_active_skill,
        source_order_speed_snapshot,
        priority,
        cause_event_step_id
    )

func _dispatch_receive_damage_segment_trigger(queued_action, battle_state, content_index, target_unit_id: String, segment_index: int, segment_total: int, segment_combat_type_id: String) -> Variant:
    if queued_action == null or battle_state == null or battle_state.chain_context == null:
        return null
    var previous_segment_index := int(battle_state.chain_context.action_segment_index)
    var previous_segment_total := int(battle_state.chain_context.action_segment_total)
    var previous_combat_type_id := String(battle_state.chain_context.action_combat_type_id)
    var previous_target_unit_id = battle_state.chain_context.target_unit_id
    battle_state.chain_context.action_segment_index = segment_index
    battle_state.chain_context.action_segment_total = segment_total
    battle_state.chain_context.action_combat_type_id = segment_combat_type_id
    battle_state.chain_context.target_unit_id = target_unit_id
    var invalid_code = trigger_batch_runner.execute_trigger_batch(
        ContentSchemaScript.TRIGGER_ON_RECEIVE_ACTION_DAMAGE_SEGMENT,
        battle_state,
        content_index,
        [target_unit_id],
        battle_state.chain_context
    )
    battle_state.chain_context.action_segment_index = previous_segment_index
    battle_state.chain_context.action_segment_total = previous_segment_total
    battle_state.chain_context.action_combat_type_id = previous_combat_type_id
    battle_state.chain_context.target_unit_id = previous_target_unit_id
    return invalid_code
