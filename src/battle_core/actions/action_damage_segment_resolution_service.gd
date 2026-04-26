extends RefCounted
class_name ActionDamageSegmentResolutionService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ActionCastDamageSegmentHelperScript := preload("res://src/battle_core/actions/action_cast_damage_segment_helper.gd")

func resolve_damage_segments(skill_definition, actor, target, power_bonus_resolver) -> Array:
	return ActionCastDamageSegmentHelperScript.resolve_damage_segments(
		skill_definition,
		actor,
		target,
		power_bonus_resolver
	)

func can_continue_damage_sequence(target) -> bool:
	return ActionCastDamageSegmentHelperScript.can_continue_damage_sequence(target)

func apply_damage_segment(
	queued_action: QueuedAction,
	actor,
	target,
	damage_segment: Dictionary,
	battle_state: BattleState,
	damage_service,
	combat_type_service,
	stat_calculator,
	rule_mod_service,
	final_multiplier: float
) -> Dictionary:
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
		var rule_error: Dictionary = rule_mod_service.error_state()
		if rule_error.get("code", null) != null:
			return {"invalid_battle_code": rule_error.get("code", null)}
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
	return {
		"before_hp": before_hp,
		"after_hp": int(target.current_hp),
		"damage_amount": damage_amount,
		"segment_combat_type_id": segment_combat_type_id,
		"type_effectiveness": type_effectiveness,
		"invalid_battle_code": null,
	}
