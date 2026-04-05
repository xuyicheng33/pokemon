extends RefCounted
class_name ContentSnapshotFormalObitoUnitPassiveContracts

const ContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_character_contract_helper.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")

var _helper = ContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_validate_unit_contract(validator, content_index, errors)
	_validate_passive_contract(validator, content_index, errors)
	_validate_yinyang_stack_contract(validator, content_index, errors)

func _validate_unit_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_unit_contract(
		validator,
		content_index,
		errors,
		"formal[obito].unit",
		"obito_juubi_jinchuriki",
		{
			"display_name": "宇智波带土·十尾人柱力",
			"base_hp": 128,
			"base_attack": 58,
			"base_defense": 78,
			"base_sp_attack": 88,
			"base_sp_defense": 80,
			"base_speed": 64,
			"max_mp": 100,
			"init_mp": 48,
			"regen_per_turn": 12,
			"ultimate_points_required": 3,
			"ultimate_points_cap": 3,
			"ultimate_point_gain_on_regular_skill_cast": 1,
			"combat_type_ids": PackedStringArray(["light", "dark"]),
			"skill_ids": PackedStringArray(["obito_qiudao_jiaotu", "obito_yinyang_dun", "obito_qiudao_yu"]),
			"candidate_skill_ids": PackedStringArray(["obito_qiudao_jiaotu", "obito_yinyang_dun", "obito_qiudao_yu", "obito_liudao_shizi_fenghuo"]),
			"ultimate_skill_id": "obito_shiwei_weishouyu",
			"passive_skill_id": "obito_xianren_zhili",
			"passive_item_id": "",
		}
	)

func _validate_passive_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[obito].xianren_zhili"
	var passive_skill = validator._require_passive_skill(content_index, errors, label, "obito_xianren_zhili")
	if passive_skill != null:
		validator._expect_string(errors, "%s display_name" % label, passive_skill.display_name, "仙人之力")
		validator._expect_packed_string_array(errors, "%s trigger_names" % label, passive_skill.trigger_names, PackedStringArray(["turn_start"]))
		validator._expect_packed_string_array(errors, "%s effect_ids" % label, passive_skill.effect_ids, PackedStringArray(["obito_xianren_zhili_heal"]))
	var effect_definition = validator._require_effect(content_index, errors, label, "obito_xianren_zhili_heal")
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s effect.scope" % label, effect_definition.scope, "self")
	validator._expect_string(errors, "%s effect.duration_mode" % label, effect_definition.duration_mode, "permanent")
	validator._expect_string(errors, "%s effect.stacking" % label, effect_definition.stacking, "none")
	validator._expect_packed_string_array(errors, "%s effect.trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["turn_start"]))
	var heal_payload = validator._extract_single_payload(
		errors,
		label,
		"obito_xianren_zhili_heal",
		effect_definition,
		HealPayloadScript,
		"heal"
	)
	validator._expect_payload_shape(
		errors,
		"%s effect" % label,
		heal_payload,
		{
			"use_percent": true,
			"percent": 10,
			"percent_base": "missing_hp",
		}
	)

func _validate_yinyang_stack_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[obito].yinyang_zhili"
	var effect_definition = validator._require_effect(content_index, errors, label, "obito_yinyang_zhili")
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s display_name" % label, effect_definition.display_name, "阴阳之力")
	validator._expect_string(errors, "%s scope" % label, effect_definition.scope, "self")
	validator._expect_string(errors, "%s duration_mode" % label, effect_definition.duration_mode, "permanent")
	validator._expect_string(errors, "%s stacking" % label, effect_definition.stacking, "stack")
	validator._expect_int(errors, "%s max_stacks" % label, effect_definition.max_stacks, 5)
	validator._expect_packed_string_array(errors, "%s trigger_names" % label, effect_definition.trigger_names, PackedStringArray())
	validator._expect_bool(errors, "%s persists_on_switch" % label, effect_definition.persists_on_switch, false)
