extends RefCounted
class_name ActionCastDirectDamagePipeline

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

var damage_service
var combat_type_service
var stat_calculator
var rule_mod_service
var faint_resolver
var action_log_service
var power_bonus_resolver

func resolve_missing_dependency() -> String:
    if damage_service == null:
        return "damage_service"
    if combat_type_service == null:
        return "combat_type_service"
    if stat_calculator == null:
        return "stat_calculator"
    if rule_mod_service == null:
        return "rule_mod_service"
    if faint_resolver == null:
        return "faint_resolver"
    if action_log_service == null:
        return "action_log_service"
    if power_bonus_resolver == null:
        return "power_bonus_resolver"
    return ""

func apply_direct_damage(queued_action, actor, target, skill_definition, battle_state, cause_event_id: String, source_kind_order_active_skill: int) -> void:
    if target == null:
        return
    var damage_context := _build_direct_damage_context(actor, target, skill_definition)
    var final_multiplier: float = rule_mod_service.get_final_multiplier(battle_state, actor.unit_instance_id)
    var incoming_action_multiplier: float = 1.0
    if queued_action != null and queued_action.command != null:
        incoming_action_multiplier = rule_mod_service.resolve_incoming_action_final_multiplier(
            battle_state,
            target.unit_instance_id,
            String(queued_action.command.command_type),
            _resolve_skill_combat_type_id(skill_definition)
        )
    var type_effectiveness: float = combat_type_service.calc_effectiveness(
        _resolve_skill_combat_type_id(skill_definition),
        _resolve_unit_combat_types(target)
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
        log_event.event_step_id,
        source_kind_order_active_skill
    )

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

func _record_fatal_damage(battle_state, target_unit_id: String, before_hp: int, after_hp: int, killer_unit_id: Variant, source_instance_id: String, priority: int, source_order_speed_snapshot: int, cause_event_step_id: int, source_kind_order_active_skill: int) -> void:
    if faint_resolver == null:
        return
    faint_resolver.record_fatal_damage(
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

func _resolve_skill_combat_type_id(skill_definition) -> String:
    if skill_definition == null or skill_definition.combat_type_id == null:
        return ""
    return str(skill_definition.combat_type_id)

func _resolve_unit_combat_types(target) -> PackedStringArray:
    if target == null or target.combat_type_ids == null:
        return PackedStringArray()
    return target.combat_type_ids

func _resolve_power_bonus(skill_definition, actor, target) -> int:
    if skill_definition == null or power_bonus_resolver == null:
        return 0
    var actor_mp_after_cost: int = int(actor.current_mp) if actor != null else 0
    var target_mp_before_cast: int = int(target.current_mp) if target != null else 0
    return int(power_bonus_resolver.resolve_power_bonus(
        skill_definition,
        actor,
        target,
        actor_mp_after_cost,
        target_mp_before_cast
    ))

func _build_direct_damage_context(actor, target, skill_definition) -> Dictionary:
    var power: int = 50
    var damage_kind: String = ContentSchemaScript.DAMAGE_KIND_PHYSICAL
    if skill_definition != null:
        power = skill_definition.power
        power += _resolve_power_bonus(skill_definition, actor, target)
        damage_kind = skill_definition.damage_kind
    return {
        "power": power,
        "attack_value": _resolve_effective_attack_value(actor, damage_kind),
        "defense_value": _resolve_effective_defense_value(target, damage_kind),
    }

func _resolve_effective_attack_value(actor, damage_kind: String) -> int:
    if damage_kind == ContentSchemaScript.DAMAGE_KIND_SPECIAL:
        return stat_calculator.calc_effective_stat(actor.base_sp_attack, actor.get_effective_stage("sp_attack"))
    return stat_calculator.calc_effective_stat(actor.base_attack, actor.get_effective_stage("attack"))

func _resolve_effective_defense_value(target, damage_kind: String) -> int:
    if damage_kind == ContentSchemaScript.DAMAGE_KIND_SPECIAL:
        return stat_calculator.calc_effective_stat(target.base_sp_defense, target.get_effective_stage("sp_defense"))
    return stat_calculator.calc_effective_stat(target.base_defense, target.get_effective_stage("defense"))
