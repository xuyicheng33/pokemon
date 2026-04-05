extends RefCounted
class_name ContentSnapshotFormalGojoContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_character_contract_helper.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate_unit_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_unit_contract(
		validator,
		content_index,
		errors,
		"formal[gojo].unit",
		"gojo_satoru",
		{
			"display_name": "五条悟",
			"base_hp": 124,
			"base_attack": 56,
			"base_defense": 60,
			"base_sp_attack": 88,
			"base_sp_defense": 68,
			"base_speed": 86,
			"max_mp": 100,
			"init_mp": 50,
			"regen_per_turn": 14,
			"ultimate_points_required": 3,
			"ultimate_points_cap": 3,
			"ultimate_point_gain_on_regular_skill_cast": 1,
			"combat_type_ids": PackedStringArray(["space", "psychic"]),
			"skill_ids": PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki"]),
			"candidate_skill_ids": PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki", "gojo_reverse_ritual"]),
			"ultimate_skill_id": "gojo_unlimited_void",
			"passive_skill_id": "gojo_mugen",
		}
	)

func validate_core_skill_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(validator, content_index, errors, [
		{
			"label": "formal[gojo].ao",
			"skill_id": "gojo_ao",
			"fields": {
				"display_name": "苍",
				"damage_kind": "special",
				"power": 44,
				"accuracy": 95,
				"mp_cost": 14,
				"priority": 0,
				"combat_type_id": "space",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["gojo_ao_speed_up", "gojo_ao_mark_apply"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[gojo].aka",
			"skill_id": "gojo_aka",
			"fields": {
				"display_name": "赫",
				"damage_kind": "special",
				"power": 44,
				"accuracy": 95,
				"mp_cost": 14,
				"priority": 0,
				"combat_type_id": "psychic",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["gojo_aka_slow_down", "gojo_aka_mark_apply"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[gojo].murasaki",
			"skill_id": "gojo_murasaki",
			"fields": {
				"display_name": "茈",
				"damage_kind": "special",
				"power": 64,
				"accuracy": 90,
				"mp_cost": 24,
				"priority": -1,
				"combat_type_id": "space",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["gojo_murasaki_conditional_burst"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[gojo].reverse_ritual",
			"skill_id": "gojo_reverse_ritual",
			"fields": {
				"display_name": "反转术式",
				"damage_kind": "none",
				"power": 0,
				"accuracy": 100,
				"mp_cost": 14,
				"priority": 0,
				"combat_type_id": "",
				"targeting": "self",
				"effects_on_cast_ids": PackedStringArray(["gojo_reverse_heal"]),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[gojo].unlimited_void",
			"skill_id": "gojo_unlimited_void",
			"fields": {
				"display_name": "无量空处",
				"damage_kind": "special",
				"power": 48,
				"accuracy": 100,
				"mp_cost": 50,
				"priority": 5,
				"combat_type_id": "space",
				"targeting": "enemy_active_slot",
				"is_domain_skill": true,
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["gojo_apply_domain_field"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
	])

func validate_marker_contract(validator, content_index, errors: Array) -> void:
	_validate_marker_effect(validator, content_index, errors, "formal[gojo].ao_mark", "gojo_ao_mark", "gojo_ao_speed_up", "speed", 1)
	_validate_marker_effect(validator, content_index, errors, "formal[gojo].aka_mark", "gojo_aka_mark", "gojo_aka_slow_down", "speed", -1)

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
	var apply_effect_id := "%s_apply" % marker_effect_id
	var apply_effect = validator._require_effect(content_index, errors, label, apply_effect_id)
	if apply_effect != null:
		validator._expect_string(errors, "%s effect[%s].scope" % [label, apply_effect_id], apply_effect.scope, "target")
		validator._expect_string(errors, "%s effect[%s].duration_mode" % [label, apply_effect_id], apply_effect.duration_mode, "permanent")
		validator._expect_string(errors, "%s effect[%s].stacking" % [label, apply_effect_id], apply_effect.stacking, "none")
		validator._expect_packed_string_array(errors, "%s effect[%s].trigger_names" % [label, apply_effect_id], apply_effect.trigger_names, PackedStringArray(["on_hit"]))
		var apply_payload = validator._extract_single_payload(errors, label, apply_effect_id, apply_effect, ApplyEffectPayloadScript, "apply_effect")
		validator._expect_payload_shape(errors, "%s effect[%s]" % [label, apply_effect_id], apply_payload, {"effect_definition_id": marker_effect_id})
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
