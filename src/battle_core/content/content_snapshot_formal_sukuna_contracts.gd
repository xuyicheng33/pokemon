extends RefCounted
class_name ContentSnapshotFormalSukunaContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

func validate_unit_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[sukuna].unit"
	var unit_definition = validator._require_unit(content_index, errors, label, "sukuna")
	if unit_definition == null:
		return
	validator._expect_string(errors, "%s display_name" % label, unit_definition.display_name, "宿傩")
	validator._expect_int(errors, "%s base_hp" % label, unit_definition.base_hp, 126)
	validator._expect_int(errors, "%s base_attack" % label, unit_definition.base_attack, 78)
	validator._expect_int(errors, "%s base_defense" % label, unit_definition.base_defense, 62)
	validator._expect_int(errors, "%s base_sp_attack" % label, unit_definition.base_sp_attack, 84)
	validator._expect_int(errors, "%s base_sp_defense" % label, unit_definition.base_sp_defense, 60)
	validator._expect_int(errors, "%s base_speed" % label, unit_definition.base_speed, 76)
	validator._expect_int(errors, "%s max_mp" % label, unit_definition.max_mp, 100)
	validator._expect_int(errors, "%s init_mp" % label, unit_definition.init_mp, 45)
	validator._expect_int(errors, "%s regen_per_turn" % label, unit_definition.regen_per_turn, 12)
	validator._expect_int(errors, "%s ultimate_points_required" % label, unit_definition.ultimate_points_required, 3)
	validator._expect_int(errors, "%s ultimate_points_cap" % label, unit_definition.ultimate_points_cap, 3)
	validator._expect_int(errors, "%s ultimate_point_gain_on_regular_skill_cast" % label, unit_definition.ultimate_point_gain_on_regular_skill_cast, 1)
	validator._expect_packed_string_array(errors, "%s combat_type_ids" % label, unit_definition.combat_type_ids, PackedStringArray(["fire", "demon"]))
	validator._expect_packed_string_array(errors, "%s skill_ids" % label, unit_definition.skill_ids, PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku"]))
	validator._expect_packed_string_array(errors, "%s candidate_skill_ids" % label, unit_definition.candidate_skill_ids, PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku", "sukuna_reverse_ritual"]))
	validator._expect_string(errors, "%s ultimate_skill_id" % label, unit_definition.ultimate_skill_id, "sukuna_fukuma_mizushi")
	validator._expect_string(errors, "%s passive_skill_id" % label, unit_definition.passive_skill_id, "sukuna_teach_love")

func validate_core_skill_contract(validator, content_index, errors: Array) -> void:
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[sukuna].kai",
		"sukuna_kai",
		{
			"display_name": "解",
			"damage_kind": "physical",
			"power": 42,
			"accuracy": 100,
			"mp_cost": 10,
			"priority": 1,
			"combat_type_id": "",
			"targeting": "enemy_active_slot",
			"effects_on_cast_ids": PackedStringArray(),
			"effects_on_hit_ids": PackedStringArray(),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		}
	)
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[sukuna].hatsu",
		"sukuna_hatsu",
		{
			"display_name": "捌",
			"damage_kind": "special",
			"power": 46,
			"accuracy": 95,
			"mp_cost": 18,
			"priority": -1,
			"combat_type_id": "",
			"targeting": "enemy_active_slot",
			"power_bonus_source": "mp_diff_clamped",
			"effects_on_cast_ids": PackedStringArray(),
			"effects_on_hit_ids": PackedStringArray(),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		}
	)
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[sukuna].hiraku",
		"sukuna_hiraku",
		{
			"display_name": "开",
			"damage_kind": "special",
			"power": 48,
			"accuracy": 90,
			"mp_cost": 22,
			"priority": -2,
			"combat_type_id": "fire",
			"targeting": "enemy_active_slot",
			"effects_on_cast_ids": PackedStringArray(),
			"effects_on_hit_ids": PackedStringArray(["sukuna_apply_kamado"]),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		}
	)
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[sukuna].reverse_ritual",
		"sukuna_reverse_ritual",
		{
			"display_name": "反转术式",
			"damage_kind": "none",
			"power": 0,
			"accuracy": 100,
			"mp_cost": 14,
			"priority": 0,
			"combat_type_id": "",
			"targeting": "self",
			"effects_on_cast_ids": PackedStringArray(["sukuna_reverse_heal"]),
			"effects_on_hit_ids": PackedStringArray(),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		}
	)
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[sukuna].fukuma_mizushi",
		"sukuna_fukuma_mizushi",
		{
			"display_name": "伏魔御厨子",
			"damage_kind": "special",
			"power": 68,
			"accuracy": 100,
			"mp_cost": 50,
			"priority": 5,
			"combat_type_id": "demon",
			"targeting": "enemy_active_slot",
			"is_domain_skill": true,
			"effects_on_cast_ids": PackedStringArray(),
			"effects_on_hit_ids": PackedStringArray(["sukuna_apply_domain_field"]),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		}
	)

func validate_kamado_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[sukuna].kamado"
	var apply_effect = validator._require_effect(content_index, errors, label, "sukuna_apply_kamado")
	if apply_effect != null:
		validator._expect_packed_string_array(errors, "%s apply.trigger_names" % label, apply_effect.trigger_names, PackedStringArray(["on_hit"]))
		var apply_payload = validator._extract_single_payload(errors, label, "sukuna_apply_kamado", apply_effect, ApplyEffectPayloadScript, "apply_effect")
		validator._expect_payload_shape(errors, "%s apply" % label, apply_payload, {"effect_definition_id": "sukuna_kamado_mark"})
	var marker_effect = validator._require_effect(content_index, errors, label, "sukuna_kamado_mark")
	if marker_effect != null:
		validator._expect_string(errors, "%s mark.duration_mode" % label, marker_effect.duration_mode, "turns")
		validator._expect_int(errors, "%s mark.duration" % label, marker_effect.duration, 3)
		validator._expect_string(errors, "%s mark.decrement_on" % label, marker_effect.decrement_on, "turn_end")
		validator._expect_string(errors, "%s mark.stacking" % label, marker_effect.stacking, "stack")
		validator._expect_int(errors, "%s mark.max_stacks" % label, marker_effect.max_stacks, 3)
		validator._expect_packed_string_array(errors, "%s mark.trigger_names" % label, marker_effect.trigger_names, PackedStringArray(["on_exit"]))
		validator._expect_packed_string_array(errors, "%s mark.on_expire_effect_ids" % label, marker_effect.on_expire_effect_ids, PackedStringArray(["sukuna_kamado_explode"]))
		validator._expect_bool(errors, "%s mark.persists_on_switch" % label, marker_effect.persists_on_switch, false)

func validate_teach_love_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[sukuna].teach_love"
	var passive_skill = validator._require_passive_skill(content_index, errors, label, "sukuna_teach_love")
	if passive_skill != null:
		validator._expect_packed_string_array(errors, "%s passive.trigger_names" % label, passive_skill.trigger_names, PackedStringArray(["on_matchup_changed"]))
		validator._expect_packed_string_array(errors, "%s passive.effect_ids" % label, passive_skill.effect_ids, PackedStringArray(["sukuna_refresh_love_regen"]))
	var effect_definition = validator._require_effect(content_index, errors, label, "sukuna_refresh_love_regen")
	if effect_definition == null:
		return
	validator._expect_packed_string_array(errors, "%s effect.trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["on_matchup_changed"]))
	var payload = validator._extract_single_payload(errors, label, "sukuna_refresh_love_regen", effect_definition, RuleModPayloadScript, "rule_mod")
	validator._expect_payload_shape(
		errors,
		"%s effect" % label,
		payload,
		{
			"mod_kind": "mp_regen",
			"mod_op": "add",
			"duration_mode": "turns",
			"duration": 999,
			"decrement_on": "turn_start",
			"stacking": "replace",
			"dynamic_value_formula": "matchup_bst_gap_band",
			"dynamic_value_default": 0.0,
		}
	)
	if payload != null:
		if payload.dynamic_value_thresholds != PackedInt32Array([20, 40, 70, 110, 160]):
			errors.append("%s effect.dynamic_value_thresholds mismatch: expected %s got %s" % [label, var_to_str(PackedInt32Array([20, 40, 70, 110, 160])), var_to_str(payload.dynamic_value_thresholds)])
		if payload.dynamic_value_outputs != PackedFloat32Array([9.0, 8.0, 7.0, 6.0, 5.0]):
			errors.append("%s effect.dynamic_value_outputs mismatch: expected %s got %s" % [label, var_to_str(PackedFloat32Array([9.0, 8.0, 7.0, 6.0, 5.0])), var_to_str(payload.dynamic_value_outputs)])

func _validate_skill_contract(
	validator,
	content_index,
	errors: Array,
	label: String,
	skill_id: String,
	expected_fields: Dictionary,
	expected_effects_on_hit: PackedStringArray = PackedStringArray()
) -> void:
	var skill_definition = validator._require_skill(content_index, errors, label, skill_id)
	if skill_definition == null:
		return
	validator._expect_string(errors, "%s display_name" % label, skill_definition.display_name, String(expected_fields.get("display_name", "")))
	validator._expect_string(errors, "%s damage_kind" % label, skill_definition.damage_kind, String(expected_fields.get("damage_kind", "")))
	validator._expect_int(errors, "%s power" % label, skill_definition.power, int(expected_fields.get("power", 0)))
	validator._expect_int(errors, "%s accuracy" % label, skill_definition.accuracy, int(expected_fields.get("accuracy", 0)))
	validator._expect_int(errors, "%s mp_cost" % label, skill_definition.mp_cost, int(expected_fields.get("mp_cost", 0)))
	validator._expect_int(errors, "%s priority" % label, skill_definition.priority, int(expected_fields.get("priority", 0)))
	validator._expect_string(errors, "%s combat_type_id" % label, skill_definition.combat_type_id, String(expected_fields.get("combat_type_id", "")))
	validator._expect_string(errors, "%s targeting" % label, skill_definition.targeting, String(expected_fields.get("targeting", "")))
	if expected_fields.has("power_bonus_source"):
		validator._expect_string(errors, "%s power_bonus_source" % label, skill_definition.power_bonus_source, String(expected_fields.get("power_bonus_source", "")))
	if expected_fields.has("is_domain_skill"):
		validator._expect_bool(errors, "%s is_domain_skill" % label, skill_definition.is_domain_skill, bool(expected_fields.get("is_domain_skill", false)))
	if expected_fields.has("effects_on_cast_ids"):
		validator._expect_packed_string_array(errors, "%s effects_on_cast_ids" % label, skill_definition.effects_on_cast_ids, expected_fields.get("effects_on_cast_ids", PackedStringArray()))
	if not expected_effects_on_hit.is_empty():
		validator._expect_packed_string_array(errors, "%s effects_on_hit_ids" % label, skill_definition.effects_on_hit_ids, expected_effects_on_hit)
	elif expected_fields.has("effects_on_hit_ids"):
		validator._expect_packed_string_array(errors, "%s effects_on_hit_ids" % label, skill_definition.effects_on_hit_ids, expected_fields.get("effects_on_hit_ids", PackedStringArray()))
	if expected_fields.has("effects_on_miss_ids"):
		validator._expect_packed_string_array(errors, "%s effects_on_miss_ids" % label, skill_definition.effects_on_miss_ids, expected_fields.get("effects_on_miss_ids", PackedStringArray()))
	if expected_fields.has("effects_on_kill_ids"):
		validator._expect_packed_string_array(errors, "%s effects_on_kill_ids" % label, skill_definition.effects_on_kill_ids, expected_fields.get("effects_on_kill_ids", PackedStringArray()))
