extends RefCounted
class_name ActionCastService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

const SOURCE_KIND_ORDER_ACTIVE_SKILL := 2

var mp_service
var hit_service
var damage_service
var combat_type_service
var stat_calculator
var rule_mod_service
var target_resolver
var trigger_dispatcher
var effect_queue_service
var payload_executor
var faint_resolver
var trigger_batch_runner
var rng_service
var action_log_service

func resolve_missing_dependency() -> String:
    if mp_service == null:
        return "mp_service"
    if hit_service == null:
        return "hit_service"
    if damage_service == null:
        return "damage_service"
    if combat_type_service == null:
        return "combat_type_service"
    if stat_calculator == null:
        return "stat_calculator"
    if rule_mod_service == null:
        return "rule_mod_service"
    if target_resolver == null:
        return "target_resolver"
    if trigger_dispatcher == null:
        return "trigger_dispatcher"
    if effect_queue_service == null:
        return "effect_queue_service"
    if payload_executor == null:
        return "payload_executor"
    if faint_resolver == null:
        return "faint_resolver"
    if trigger_batch_runner == null:
        return "trigger_batch_runner"
    if rng_service == null:
        return "rng_service"
    if action_log_service == null:
        return "action_log_service"
    return ""

func resolve_mp_cost(command, skill_definition) -> int:
    if command.command_type == CommandTypesScript.SKILL or command.command_type == CommandTypesScript.ULTIMATE:
        return skill_definition.mp_cost
    return 0

func consume_mp(actor, consumed_mp: int) -> Array:
    var mp_changes: Array = []
    if consumed_mp > 0:
        var before_mp: int = actor.current_mp
        actor.current_mp = mp_service.consume_mp(actor.current_mp, consumed_mp)
        mp_changes.append(action_log_service.build_value_change(actor.unit_instance_id, "mp", before_mp, actor.current_mp))
    return mp_changes

func resolve_target(queued_action, battle_state):
    return target_resolver.resolve_target(queued_action, battle_state)

func is_action_target_valid(command, queued_action, resolved_target) -> bool:
    if command.command_type == CommandTypesScript.SWITCH:
        return true
    if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
        return true
    if resolved_target == null:
        return false
    return resolved_target.leave_state == LeaveStatesScript.ACTIVE and resolved_target.current_hp > 0

func resolve_target_instance_id(queued_action, resolved_target):
    if resolved_target == null:
        return null
    if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
        return null
    return resolved_target.unit_instance_id

func resolve_hit(command, skill_definition, resolved_target, battle_state, content_index) -> Dictionary:
    if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT:
        return {"hit": true, "hit_roll": null}
    var resolved_accuracy: int = int(skill_definition.accuracy)
    if battle_state.field_state != null and command.actor_id == battle_state.field_state.creator:
        var field_definition = content_index.fields.get(battle_state.field_state.field_def_id) if content_index != null else null
        if field_definition != null and int(field_definition.creator_accuracy_override) >= 0:
            resolved_accuracy = int(field_definition.creator_accuracy_override)
    if resolved_accuracy < 100 and _should_read_incoming_accuracy(command, skill_definition, resolved_target, battle_state):
        resolved_accuracy = rule_mod_service.resolve_incoming_accuracy(
            battle_state,
            resolved_target.unit_instance_id,
            resolved_accuracy
        )
    var hit_info: Dictionary = hit_service.roll_hit(resolved_accuracy, rng_service)
    battle_state.rng_stream_index = rng_service.get_stream_index()
    return hit_info

func is_damage_action(command, skill_definition) -> bool:
    if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT:
        return true
    return skill_definition != null and skill_definition.damage_kind != ContentSchemaScript.DAMAGE_KIND_NONE and skill_definition.power > 0

func apply_direct_damage(queued_action, actor, target, skill_definition, battle_state, cause_event_id: String) -> void:
    if target == null:
        return
    var power: int = 50
    var damage_kind: String = ContentSchemaScript.DAMAGE_KIND_PHYSICAL
    if skill_definition != null:
        power = skill_definition.power
        power += _resolve_power_bonus(skill_definition, actor, target)
        damage_kind = skill_definition.damage_kind
    var attack_value: int = actor.base_attack
    var defense_value: int = target.base_defense
    if damage_kind == ContentSchemaScript.DAMAGE_KIND_SPECIAL:
        attack_value = actor.base_sp_attack
        defense_value = target.base_sp_defense
    attack_value = stat_calculator.calc_effective_stat(attack_value, int(actor.stat_stages.get("attack" if damage_kind == ContentSchemaScript.DAMAGE_KIND_PHYSICAL else "sp_attack", 0)))
    defense_value = stat_calculator.calc_effective_stat(defense_value, int(target.stat_stages.get("defense" if damage_kind == ContentSchemaScript.DAMAGE_KIND_PHYSICAL else "sp_defense", 0)))
    var final_multiplier: float = rule_mod_service.get_final_multiplier(battle_state, actor.unit_instance_id)
    var type_effectiveness: float = combat_type_service.calc_effectiveness(
        _resolve_skill_combat_type_id(skill_definition),
        _resolve_unit_combat_types(target)
    )
    var damage_amount: int = damage_service.apply_final_mod(
        damage_service.calc_base_damage(battle_state.battle_level, power, attack_value, defense_value),
        final_multiplier * type_effectiveness
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
        cause_event_id
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
        log_event.event_step_id
    )

func apply_default_recoil(queued_action, actor, battle_state, cause_event_id: String) -> void:
    var recoil_amount: int = max(1, int(floor(float(actor.max_hp) / 4.0)))
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
        log_event.event_step_id
    )

func dispatch_skill_effects(effect_ids: PackedStringArray, trigger_name: String, queued_action, actor, battle_state, content_index, result) -> void:
    if effect_ids.is_empty():
        return
    var effect_events = trigger_dispatcher.collect_events(
        trigger_name,
        battle_state,
        content_index,
        effect_ids,
        actor.unit_instance_id,
        queued_action.action_id,
        SOURCE_KIND_ORDER_ACTIVE_SKILL,
        queued_action.speed_snapshot,
        battle_state.chain_context
    )
    if effect_events.is_empty():
        return
    battle_state.pending_effect_queue = effect_events
    var sorted_events = effect_queue_service.sort_events(effect_events, rng_service)
    battle_state.rng_stream_index = rng_service.get_stream_index()
    for effect_event in sorted_events:
        payload_executor.execute_effect_event(effect_event, battle_state, content_index)
        if payload_executor.last_invalid_battle_code != null:
            result.invalid_battle_code = payload_executor.last_invalid_battle_code
            break
        result.generated_effects.append(effect_event)
    battle_state.pending_effect_queue.clear()

func execute_lifecycle_trigger_batch(trigger_name: String, battle_state, content_index, owner_unit_ids: Array):
    return trigger_batch_runner.execute_trigger_batch(
        trigger_name,
        battle_state,
        content_index,
        owner_unit_ids,
        battle_state.chain_context
    )

func _record_fatal_damage(battle_state, target_unit_id: String, before_hp: int, after_hp: int, killer_unit_id: Variant, source_instance_id: String, priority: int, source_order_speed_snapshot: int, cause_event_step_id: int) -> void:
    if faint_resolver == null:
        return
    faint_resolver.record_fatal_damage(
        battle_state,
        target_unit_id,
        before_hp,
        after_hp,
        killer_unit_id,
        source_instance_id,
        SOURCE_KIND_ORDER_ACTIVE_SKILL,
        source_order_speed_snapshot,
        priority,
        cause_event_step_id
    )

func _resolve_skill_combat_type_id(skill_definition) -> String:
    if skill_definition == null or skill_definition.combat_type_id == null:
        return ""
    return str(skill_definition.combat_type_id)

func _resolve_unit_combat_types(target) -> PackedStringArray:
    if target == null or target.combat_type_ids == null:
        return PackedStringArray()
    return target.combat_type_ids

func _resolve_power_bonus(skill_definition, actor, target) -> int:
    if skill_definition == null or target == null:
        return 0
    if String(skill_definition.power_bonus_source) == "mp_diff_clamped":
        return max(0, int(actor.current_mp) - int(target.current_mp))
    return 0

func _should_read_incoming_accuracy(command, skill_definition, resolved_target, battle_state) -> bool:
    if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
        return false
    if skill_definition == null or String(skill_definition.targeting) != ContentSchemaScript.TARGET_ENEMY_ACTIVE:
        return false
    if resolved_target == null or resolved_target.leave_state != LeaveStatesScript.ACTIVE or resolved_target.current_hp <= 0:
        return false
    var actor_side = battle_state.get_side_for_unit(command.actor_id)
    var target_side = battle_state.get_side_for_unit(resolved_target.unit_instance_id)
    return actor_side != null and target_side != null and actor_side.side_id != target_side.side_id
