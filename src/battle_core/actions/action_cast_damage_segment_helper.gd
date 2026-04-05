extends RefCounted
class_name ActionCastDamageSegmentHelper

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const SkillDamageSegmentScript := preload("res://src/battle_core/content/skill_damage_segment.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

static func resolve_damage_segments(skill_definition, actor, target, power_bonus_resolver) -> Array:
	var resolved_segments: Array = []
	if skill_definition == null or skill_definition.damage_segments.is_empty():
		resolved_segments.append({
			"power": (skill_definition.power + resolve_power_bonus(skill_definition, actor, target, power_bonus_resolver)) if skill_definition != null else 50,
			"damage_kind": skill_definition.damage_kind if skill_definition != null else ContentSchemaScript.DAMAGE_KIND_PHYSICAL,
			"combat_type_id": resolve_skill_combat_type_id(skill_definition),
		})
		return resolved_segments
	for raw_segment in skill_definition.damage_segments:
		if raw_segment == null or not raw_segment is SkillDamageSegmentScript:
			continue
		var segment = raw_segment as SkillDamageSegmentScript
		for _repeat_index in range(max(0, int(segment.repeat_count))):
			resolved_segments.append({
				"power": int(segment.power),
				"damage_kind": String(segment.damage_kind),
				"combat_type_id": String(segment.combat_type_id),
			})
	return resolved_segments

static func resolve_power_bonus(skill_definition, actor, target, power_bonus_resolver) -> int:
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

static func build_direct_damage_context(actor, target, power: int, damage_kind: String, stat_calculator) -> Dictionary:
	return {
		"power": power,
		"attack_value": resolve_effective_attack_value(actor, damage_kind, stat_calculator),
		"defense_value": resolve_effective_defense_value(target, damage_kind, stat_calculator),
	}

static func can_continue_damage_sequence(target) -> bool:
	return target != null and target.current_hp > 0 and target.leave_state == LeaveStatesScript.ACTIVE

static func resolve_unit_combat_types(target) -> PackedStringArray:
	if target == null or target.combat_type_ids == null:
		return PackedStringArray()
	return target.combat_type_ids

static func resolve_skill_combat_type_id(skill_definition) -> String:
	if skill_definition == null or skill_definition.combat_type_id == null:
		return ""
	return str(skill_definition.combat_type_id)

static func resolve_effective_attack_value(actor, damage_kind: String, stat_calculator) -> int:
	if damage_kind == ContentSchemaScript.DAMAGE_KIND_SPECIAL:
		return stat_calculator.calc_effective_stat(actor.base_sp_attack, actor.get_effective_stage("sp_attack"))
	return stat_calculator.calc_effective_stat(actor.base_attack, actor.get_effective_stage("attack"))

static func resolve_effective_defense_value(target, damage_kind: String, stat_calculator) -> int:
	if damage_kind == ContentSchemaScript.DAMAGE_KIND_SPECIAL:
		return stat_calculator.calc_effective_stat(target.base_sp_defense, target.get_effective_stage("sp_defense"))
	return stat_calculator.calc_effective_stat(target.base_defense, target.get_effective_stage("defense"))
