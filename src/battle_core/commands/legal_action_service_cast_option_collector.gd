extends RefCounted
class_name LegalActionServiceCastOptionCollector

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

var rule_gate

func collect_cast_action_flags_result(
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
		var skill_resolution_result: Dictionary = _resolve_skill_legality_result(
			battle_state,
			actor,
			skill_id,
			content_index,
			side_domain_recast_blocked
		)
		if not bool(skill_resolution_result.get("ok", false)):
			return skill_resolution_result
		var skill_resolution: Dictionary = skill_resolution_result.get("data", {})
		if bool(skill_resolution["is_legal"]):
			legal_action_set.legal_skill_ids.append(skill_id)
			has_any_skill_or_ultimate_option = true
			continue
		if bool(skill_resolution["blocked_non_mp"]):
			has_non_mp_blocked_option = true
	var ultimate_resolution_result: Dictionary = _resolve_ultimate_legality_result(
		battle_state,
		actor,
		unit_definition,
		content_index,
		side_domain_recast_blocked
	)
	if not bool(ultimate_resolution_result.get("ok", false)):
		return ultimate_resolution_result
	var ultimate_resolution: Dictionary = ultimate_resolution_result.get("data", {})
	if bool(ultimate_resolution["is_legal"]):
		has_any_skill_or_ultimate_option = true
		legal_action_set.legal_ultimate_ids.append(unit_definition.ultimate_skill_id)
	elif bool(ultimate_resolution["blocked_non_mp"]):
		has_non_mp_blocked_option = true
	return _ok_result({
		"has_non_mp_blocked_option": has_non_mp_blocked_option,
		"has_any_skill_or_ultimate_option": has_any_skill_or_ultimate_option,
	})

func _resolve_skill_legality_result(
	battle_state,
	actor,
	skill_id: String,
	content_index,
	side_domain_recast_blocked: bool
) -> Dictionary:
	var skill_definition = content_index.skills.get(skill_id)
	if skill_definition == null:
		return _ok_result({"is_legal": false, "blocked_non_mp": false})
	var blocked_by_once_per_battle: bool = bool(skill_definition.once_per_battle) and actor.has_used_once_per_battle_skill(skill_id)
	var blocked_by_side_domain: bool = side_domain_recast_blocked and content_index.is_domain_skill(skill_id)
	var allowed_by_rule_mod_result: Dictionary = rule_gate.action_allowed_result(
		battle_state,
		actor.unit_instance_id,
		CommandTypesScript.SKILL,
		skill_id
	)
	if not bool(allowed_by_rule_mod_result.get("ok", false)):
		return allowed_by_rule_mod_result
	var allowed_by_rule_mod: bool = bool(allowed_by_rule_mod_result.get("data", false))
	return _ok_result({
		"is_legal": actor.current_mp >= skill_definition.mp_cost and allowed_by_rule_mod and not blocked_by_side_domain and not blocked_by_once_per_battle,
		"blocked_non_mp": blocked_by_side_domain or not allowed_by_rule_mod or blocked_by_once_per_battle,
	})

func _resolve_ultimate_legality_result(
	battle_state,
	actor,
	unit_definition,
	content_index,
	side_domain_recast_blocked: bool
) -> Dictionary:
	if unit_definition == null or unit_definition.ultimate_skill_id.is_empty():
		return _ok_result({"is_legal": false, "blocked_non_mp": false})
	var ultimate_definition = content_index.skills.get(unit_definition.ultimate_skill_id)
	if ultimate_definition == null:
		return _ok_result({"is_legal": false, "blocked_non_mp": false})
	var blocked_by_once_per_battle: bool = bool(ultimate_definition.once_per_battle) and actor.has_used_once_per_battle_skill(unit_definition.ultimate_skill_id)
	var blocked_by_side_domain: bool = side_domain_recast_blocked and content_index.is_domain_skill(unit_definition.ultimate_skill_id)
	var allowed_by_rule_mod_result: Dictionary = rule_gate.action_allowed_result(
		battle_state,
		actor.unit_instance_id,
		CommandTypesScript.ULTIMATE,
		unit_definition.ultimate_skill_id
	)
	if not bool(allowed_by_rule_mod_result.get("ok", false)):
		return allowed_by_rule_mod_result
	var allowed_by_rule_mod: bool = bool(allowed_by_rule_mod_result.get("data", false))
	return _ok_result({
		"is_legal": actor.current_mp >= ultimate_definition.mp_cost \
			and actor.ultimate_points >= actor.ultimate_points_required \
			and allowed_by_rule_mod \
			and not blocked_by_side_domain \
			and not blocked_by_once_per_battle,
		"blocked_non_mp": blocked_by_side_domain or not allowed_by_rule_mod or blocked_by_once_per_battle,
	})

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}
