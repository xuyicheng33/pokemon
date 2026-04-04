extends RefCounted
class_name ContentSnapshotFormalGojoContracts

const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

func validate_unit_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[gojo].unit"
	var unit_definition = validator._require_unit(content_index, errors, label, "gojo_satoru")
	if unit_definition == null:
		return
	validator._expect_string(errors, "%s display_name" % label, unit_definition.display_name, "五条悟")
	validator._expect_int(errors, "%s base_hp" % label, unit_definition.base_hp, 124)
	validator._expect_int(errors, "%s base_attack" % label, unit_definition.base_attack, 56)
	validator._expect_int(errors, "%s base_defense" % label, unit_definition.base_defense, 60)
	validator._expect_int(errors, "%s base_sp_attack" % label, unit_definition.base_sp_attack, 88)
	validator._expect_int(errors, "%s base_sp_defense" % label, unit_definition.base_sp_defense, 68)
	validator._expect_int(errors, "%s base_speed" % label, unit_definition.base_speed, 86)
	validator._expect_int(errors, "%s max_mp" % label, unit_definition.max_mp, 100)
	validator._expect_int(errors, "%s init_mp" % label, unit_definition.init_mp, 50)
	validator._expect_int(errors, "%s regen_per_turn" % label, unit_definition.regen_per_turn, 14)
	validator._expect_int(errors, "%s ultimate_points_required" % label, unit_definition.ultimate_points_required, 3)
	validator._expect_int(errors, "%s ultimate_points_cap" % label, unit_definition.ultimate_points_cap, 3)
	validator._expect_int(errors, "%s ultimate_point_gain_on_regular_skill_cast" % label, unit_definition.ultimate_point_gain_on_regular_skill_cast, 1)
	validator._expect_packed_string_array(errors, "%s skill_ids" % label, unit_definition.skill_ids, PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki"]))
	validator._expect_packed_string_array(errors, "%s candidate_skill_ids" % label, unit_definition.candidate_skill_ids, PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki", "gojo_reverse_ritual"]))
	validator._expect_string(errors, "%s ultimate_skill_id" % label, unit_definition.ultimate_skill_id, "gojo_unlimited_void")
	validator._expect_string(errors, "%s passive_skill_id" % label, unit_definition.passive_skill_id, "gojo_mugen")

func validate_core_skill_contract(validator, content_index, errors: Array) -> void:
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[gojo].ao",
		"gojo_ao",
		{
			"display_name": "苍",
			"damage_kind": "special",
			"power": 44,
			"accuracy": 95,
			"mp_cost": 14,
			"priority": 0,
			"combat_type_id": "space",
			"targeting": "enemy_active_slot",
			"effects_on_hit_ids": PackedStringArray(["gojo_ao_speed_up", "gojo_ao_mark_apply"]),
		}
	)
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[gojo].aka",
		"gojo_aka",
		{
			"display_name": "赫",
			"damage_kind": "special",
			"power": 44,
			"accuracy": 95,
			"mp_cost": 14,
			"priority": 0,
			"combat_type_id": "psychic",
			"targeting": "enemy_active_slot",
			"effects_on_hit_ids": PackedStringArray(["gojo_aka_slow_down", "gojo_aka_mark_apply"]),
		}
	)
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[gojo].murasaki",
		"gojo_murasaki",
		{
			"display_name": "茈",
			"damage_kind": "special",
			"power": 64,
			"accuracy": 90,
			"mp_cost": 24,
			"priority": -1,
			"combat_type_id": "space",
			"targeting": "enemy_active_slot",
			"effects_on_hit_ids": PackedStringArray(["gojo_murasaki_conditional_burst"]),
		}
	)
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[gojo].reverse_ritual",
		"gojo_reverse_ritual",
		{
			"display_name": "反转术式",
			"damage_kind": "none",
			"power": 0,
			"accuracy": 100,
			"mp_cost": 14,
			"priority": 0,
			"combat_type_id": "",
			"targeting": "self",
			"effects_on_cast_ids": PackedStringArray(["gojo_reverse_heal"]),
		}
	)
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[gojo].unlimited_void",
		"gojo_unlimited_void",
		{
			"display_name": "无量空处",
			"damage_kind": "special",
			"power": 48,
			"accuracy": 100,
			"mp_cost": 50,
			"priority": 5,
			"combat_type_id": "space",
			"targeting": "enemy_active_slot",
			"is_domain_skill": true,
			"effects_on_hit_ids": PackedStringArray(["gojo_apply_domain_field"]),
		}
	)

func validate_marker_contract(validator, content_index, errors: Array) -> void:
	_validate_marker_effect(validator, content_index, errors, "formal[gojo].ao_mark", "gojo_ao_mark", "gojo_ao_speed_up", "speed", 1)
	_validate_marker_effect(validator, content_index, errors, "formal[gojo].aka_mark", "gojo_aka_mark", "gojo_aka_slow_down", "speed", -1)

func _validate_skill_contract(
	validator,
	content_index,
	errors: Array,
	label: String,
	skill_id: String,
	expected_fields: Dictionary
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
	if expected_fields.has("is_domain_skill"):
		validator._expect_bool(errors, "%s is_domain_skill" % label, skill_definition.is_domain_skill, bool(expected_fields.get("is_domain_skill", false)))
	if expected_fields.has("effects_on_cast_ids"):
		validator._expect_packed_string_array(errors, "%s effects_on_cast_ids" % label, skill_definition.effects_on_cast_ids, expected_fields.get("effects_on_cast_ids", PackedStringArray()))
	if expected_fields.has("effects_on_hit_ids"):
		validator._expect_packed_string_array(errors, "%s effects_on_hit_ids" % label, skill_definition.effects_on_hit_ids, expected_fields.get("effects_on_hit_ids", PackedStringArray()))

func _validate_marker_effect(
	validator,
	content_index,
	errors: Array,
	label: String,
	marker_effect_id: String,
	stat_effect_id: String,
	expected_stat_name: String,
	expected_stage_delta: int
) -> void:
	var marker_effect = validator._require_effect(content_index, errors, label, marker_effect_id)
	if marker_effect != null:
		validator._expect_string(errors, "%s scope" % label, marker_effect.scope, "self")
		validator._expect_string(errors, "%s duration_mode" % label, marker_effect.duration_mode, "turns")
		validator._expect_int(errors, "%s duration" % label, marker_effect.duration, 3)
		validator._expect_string(errors, "%s decrement_on" % label, marker_effect.decrement_on, "turn_end")
		validator._expect_string(errors, "%s stacking" % label, marker_effect.stacking, "refresh")
		validator._expect_bool(errors, "%s persists_on_switch" % label, marker_effect.persists_on_switch, false)
	var stat_effect = validator._require_effect(content_index, errors, label, stat_effect_id)
	if stat_effect == null:
		return
	var stat_payload = validator._extract_single_payload(errors, label, stat_effect_id, stat_effect, StatModPayloadScript, "stat_mod")
	if stat_payload == null:
		return
	validator._expect_packed_string_array(errors, "%s effect[%s].trigger_names" % [label, stat_effect_id], stat_effect.trigger_names, PackedStringArray(["on_hit"]))
	validator._expect_payload_shape(
		errors,
		"%s effect[%s]" % [label, stat_effect_id],
		stat_payload,
		{
			"stat_name": expected_stat_name,
			"stage_delta": expected_stage_delta,
		}
	)
