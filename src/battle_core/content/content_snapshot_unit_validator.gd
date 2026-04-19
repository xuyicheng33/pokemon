extends RefCounted
class_name ContentSnapshotUnitValidator

func validate_units(content_index: BattleContentIndex, errors: Array, regular_skill_refs: Dictionary, ultimate_skill_refs: Dictionary) -> void:
	for unit_id in content_index.units.keys():
		var unit_definition = content_index.units[unit_id]
		_validate_unit_ultimate_config(errors, unit_id, unit_definition)
		_validate_unit_combat_types(content_index, errors, unit_id, unit_definition)
		_validate_unit_regular_skills(content_index, errors, unit_id, unit_definition, regular_skill_refs)
		_validate_unit_candidate_skills(content_index, errors, unit_id, unit_definition, regular_skill_refs)
		_validate_unit_ultimate_skill(content_index, errors, unit_id, unit_definition, ultimate_skill_refs)
		_validate_unit_passives(content_index, errors, unit_id, unit_definition)

func _validate_unit_ultimate_config(errors: Array, unit_id: String, unit_definition) -> void:
	if int(unit_definition.ultimate_points_required) < 0:
		errors.append("unit[%s].ultimate_points_required must be >= 0, got %d" % [unit_id, int(unit_definition.ultimate_points_required)])
	if int(unit_definition.ultimate_points_cap) < 0:
		errors.append("unit[%s].ultimate_points_cap must be >= 0, got %d" % [unit_id, int(unit_definition.ultimate_points_cap)])
	if int(unit_definition.ultimate_point_gain_on_regular_skill_cast) < 0:
		errors.append("unit[%s].ultimate_point_gain_on_regular_skill_cast must be >= 0, got %d" % [unit_id, int(unit_definition.ultimate_point_gain_on_regular_skill_cast)])
	if int(unit_definition.ultimate_points_cap) < int(unit_definition.ultimate_points_required):
		errors.append("unit[%s].ultimate_points_cap must be >= ultimate_points_required" % unit_id)

func _validate_unit_combat_types(content_index: BattleContentIndex, errors: Array, unit_id: String, unit_definition) -> void:
	if unit_definition.combat_type_ids.size() > 2:
		errors.append("unit[%s].combat_type_ids must contain at most 2 entries, got %d" % [unit_id, unit_definition.combat_type_ids.size()])
	var seen_unit_types: Dictionary = {}
	for combat_type_id in unit_definition.combat_type_ids:
		var normalized_type_id := String(combat_type_id).strip_edges()
		if normalized_type_id.is_empty():
			errors.append("unit[%s].combat_type_ids must not contain empty entry" % unit_id)
			continue
		if seen_unit_types.has(normalized_type_id):
			errors.append("unit[%s].combat_type_ids duplicated type: %s" % [unit_id, normalized_type_id])
			continue
		seen_unit_types[normalized_type_id] = true
		if not content_index.combat_types.has(normalized_type_id):
			errors.append("unit[%s].combat_type_ids missing combat type: %s" % [unit_id, normalized_type_id])

func _validate_unit_regular_skills(content_index: BattleContentIndex, errors: Array, unit_id: String, unit_definition, regular_skill_refs: Dictionary) -> void:
	if unit_definition.skill_ids.size() != 3:
		errors.append("unit[%s].skill_ids must contain exactly 3 entries, got %d" % [unit_id, unit_definition.skill_ids.size()])
	for skill_id in unit_definition.skill_ids:
		regular_skill_refs[skill_id] = true
		if not content_index.skills.has(skill_id):
			errors.append("unit[%s].skill_ids missing skill: %s" % [unit_id, skill_id])

func _validate_unit_candidate_skills(content_index: BattleContentIndex, errors: Array, unit_id: String, unit_definition, regular_skill_refs: Dictionary) -> void:
	if unit_definition.candidate_skill_ids.is_empty():
		return
	if unit_definition.candidate_skill_ids.size() < 3:
		errors.append("unit[%s].candidate_skill_ids must contain at least 3 entries, got %d" % [unit_id, unit_definition.candidate_skill_ids.size()])
	var seen_candidate_skills: Dictionary = {}
	for candidate_skill_id in unit_definition.candidate_skill_ids:
		var normalized_candidate_skill_id := String(candidate_skill_id).strip_edges()
		regular_skill_refs[normalized_candidate_skill_id] = true
		if normalized_candidate_skill_id.is_empty():
			errors.append("unit[%s].candidate_skill_ids must not contain empty entry" % unit_id)
			continue
		if seen_candidate_skills.has(normalized_candidate_skill_id):
			errors.append("unit[%s].candidate_skill_ids duplicated skill: %s" % [unit_id, normalized_candidate_skill_id])
			continue
		seen_candidate_skills[normalized_candidate_skill_id] = true
		if not content_index.skills.has(normalized_candidate_skill_id):
			errors.append("unit[%s].candidate_skill_ids missing skill: %s" % [unit_id, normalized_candidate_skill_id])
		if normalized_candidate_skill_id == unit_definition.ultimate_skill_id and not unit_definition.ultimate_skill_id.is_empty():
			errors.append("unit[%s].candidate_skill_ids must not include ultimate_skill_id: %s" % [unit_id, normalized_candidate_skill_id])
	for default_skill_id in unit_definition.skill_ids:
		if not unit_definition.candidate_skill_ids.has(default_skill_id):
			errors.append("unit[%s].candidate_skill_ids must include default skill: %s" % [unit_id, default_skill_id])

func _validate_unit_ultimate_skill(content_index: BattleContentIndex, errors: Array, unit_id: String, unit_definition, ultimate_skill_refs: Dictionary) -> void:
	if not unit_definition.ultimate_skill_id.is_empty():
		ultimate_skill_refs[unit_definition.ultimate_skill_id] = true
		if not content_index.skills.has(unit_definition.ultimate_skill_id):
			errors.append("unit[%s].ultimate_skill_id missing skill: %s" % [unit_id, unit_definition.ultimate_skill_id])
		if unit_definition.skill_ids.has(unit_definition.ultimate_skill_id):
			errors.append("unit[%s].ultimate_skill_id duplicated in skill_ids: %s" % [unit_id, unit_definition.ultimate_skill_id])
		return
	if int(unit_definition.ultimate_points_required) != 0 \
	or int(unit_definition.ultimate_points_cap) != 0 \
	or int(unit_definition.ultimate_point_gain_on_regular_skill_cast) != 0:
		errors.append("unit[%s].ultimate point config requires ultimate_skill_id" % unit_id)

func _validate_unit_passives(content_index: BattleContentIndex, errors: Array, unit_id: String, unit_definition) -> void:
	if not unit_definition.passive_skill_id.is_empty() and not content_index.passive_skills.has(unit_definition.passive_skill_id):
		errors.append("unit[%s].passive_skill_id missing passive skill: %s" % [unit_id, unit_definition.passive_skill_id])
	if not unit_definition.passive_item_id.is_empty() and not content_index.passive_items.has(unit_definition.passive_item_id):
		errors.append("unit[%s].passive_item_id missing passive item: %s" % [unit_id, unit_definition.passive_item_id])
