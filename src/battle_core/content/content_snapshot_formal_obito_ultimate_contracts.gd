extends RefCounted
class_name ContentSnapshotFormalObitoUltimateContracts

const ContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_character_contract_helper.gd")
const SkillDamageSegmentScript := preload("res://src/battle_core/content/skill_damage_segment.gd")

var _helper = ContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(validator, content_index, errors, [
		{
			"label": "formal[obito].shiwei_weishouyu",
			"skill_id": "obito_shiwei_weishouyu",
			"fields": {
				"display_name": "十尾尾兽玉",
				"damage_kind": "special",
				"power": 12,
				"accuracy": 100,
				"mp_cost": 50,
				"priority": 5,
				"combat_type_id": "",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
	])
	var label := "formal[obito].shiwei_weishouyu"
	var skill_definition = validator._require_skill(content_index, errors, label, "obito_shiwei_weishouyu")
	if skill_definition == null:
		return
	if skill_definition.damage_segments.size() != 2:
		errors.append("%s damage_segments size mismatch: expected 2 got %d" % [label, skill_definition.damage_segments.size()])
		return
	_validate_segment(errors, label, skill_definition.damage_segments[0], 0, 2, 12, "dark", "special")
	_validate_segment(errors, label, skill_definition.damage_segments[1], 1, 8, 12, "light", "special")

func _validate_segment(
	errors: Array,
	label: String,
	raw_segment,
	index: int,
	expected_repeat_count: int,
	expected_power: int,
	expected_combat_type_id: String,
	expected_damage_kind: String
) -> void:
	if raw_segment == null or not raw_segment is SkillDamageSegmentScript:
		errors.append("%s damage_segments[%d] invalid type" % [label, index])
		return
	var segment := raw_segment as SkillDamageSegmentScript
	if int(segment.repeat_count) != expected_repeat_count:
		errors.append("%s damage_segments[%d].repeat_count mismatch: expected %d got %d" % [
			label,
			index,
			expected_repeat_count,
			int(segment.repeat_count),
		])
	if int(segment.power) != expected_power:
		errors.append("%s damage_segments[%d].power mismatch: expected %d got %d" % [
			label,
			index,
			expected_power,
			int(segment.power),
		])
	if String(segment.combat_type_id) != expected_combat_type_id:
		errors.append("%s damage_segments[%d].combat_type_id mismatch: expected %s got %s" % [
			label,
			index,
			expected_combat_type_id,
			String(segment.combat_type_id),
		])
	if String(segment.damage_kind) != expected_damage_kind:
		errors.append("%s damage_segments[%d].damage_kind mismatch: expected %s got %s" % [
			label,
			index,
			expected_damage_kind,
			String(segment.damage_kind),
		])
