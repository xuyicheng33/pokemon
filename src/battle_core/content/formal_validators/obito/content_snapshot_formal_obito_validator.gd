extends "res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalObitoValidator

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const SkillDamageSegmentScript := preload("res://src/battle_core/content/skill_damage_segment.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate(content_index: BattleContentIndex, errors: Array) -> void:
	_validate_unit_passive(content_index, errors)
	_validate_skill_effect(content_index, errors)
	_validate_ultimate_domain(content_index, errors)

func _validate_unit_passive(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_unit_contract_descriptor(
		self,
		content_index,
		errors,
		FormalCharacterBaselinesScript.unit_contract("obito_juubi_jinchuriki")
	)
	_validate_passive_contract(content_index, errors)
	_validate_yinyang_stack_contract(content_index, errors)

func _validate_passive_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[obito_juubi_jinchuriki].xianren_zhili"
	_helper.validate_passive_skill_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.passive_contract("obito_juubi_jinchuriki", "obito_xianren_zhili", label)]
	)
	_validate_single_payload_effect(
		content_index, errors,
		"obito_juubi_jinchuriki", label, "obito_xianren_zhili_heal",
		HealPayloadScript, "heal",
		{
			"use_percent": true,
			"percent": 10,
			"percent_base": "missing_hp",
		}
	)

func _validate_yinyang_stack_contract(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_zhili")]
	)

func _validate_skill_effect(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_skill_contracts(
		self,
		content_index,
		errors,
		FormalCharacterBaselinesScript.skill_contracts(
			"obito_juubi_jinchuriki",
			PackedStringArray([
				"obito_qiudao_jiaotu",
				"obito_yinyang_dun",
				"obito_qiudao_yu",
				"obito_liudao_shizi_fenghuo",
			])
		)
	)
	_validate_heal_block_contracts(content_index, errors)
	_validate_yinyang_dun_contracts(content_index, errors)
	_validate_qiudaoyu_contracts(content_index, errors)

func _validate_heal_block_contracts(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[obito_juubi_jinchuriki].heal_block"
	_validate_single_payload_effect(
		content_index, errors,
		"obito_juubi_jinchuriki", label, "obito_qiudao_jiaotu_heal_block_apply",
		ApplyEffectPayloadScript, "apply_effect",
		{"effect_definition_id": "obito_qiudao_jiaotu_heal_block_mark"},
		"apply"
	)
	var mark_effect = _require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_mark")
	if mark_effect != null:
		_helper.validate_effect_contracts(
			self,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_jiaotu_heal_block_mark", "%s mark" % label)]
		)
	_validate_single_payload_effect(
		content_index, errors,
		"obito_juubi_jinchuriki", label, "obito_qiudao_jiaotu_heal_block_rule_mod",
		RuleModPayloadScript, "rule_mod",
		{
			"mod_kind": "incoming_heal_final_mod",
			"mod_op": "set",
			"value": 0.0,
			"scope": "target",
			"duration_mode": "turns",
			"duration": 2,
			"decrement_on": "turn_end",
			"stacking": "refresh",
			"priority": 10,
			"persists_on_switch": true,
		},
		"rule_mod"
	)

func _validate_yinyang_dun_contracts(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[obito_juubi_jinchuriki].yinyang_dun"
	var boost_effect = _require_effect(content_index, errors, label, "obito_yinyang_dun_boost_and_charge")
	if boost_effect != null:
		_helper.validate_effect_contracts(
			self,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_dun_boost_and_charge", "%s boost" % label)]
		)
		if boost_effect.payloads.size() != 3:
			errors.append("%s boost payload count mismatch: expected 3 got %d" % [label, boost_effect.payloads.size()])
		else:
			_helper.expect_typed_payload_shape(
				self,
				errors,
				"%s boost.payload[0]" % label,
				boost_effect.payloads[0],
				ApplyEffectPayloadScript,
				"apply_effect",
				{"effect_definition_id": "obito_yinyang_zhili"}
			)
			_helper.expect_typed_payload_shape(
				self,
				errors,
				"%s boost.payload[1]" % label,
				boost_effect.payloads[1],
				StatModPayloadScript,
				"stat_mod",
				{"stat_name": "defense", "stage_delta": 1, "retention_mode": "normal"}
			)
			_helper.expect_typed_payload_shape(
				self,
				errors,
				"%s boost.payload[2]" % label,
				boost_effect.payloads[2],
				StatModPayloadScript,
				"stat_mod",
				{"stat_name": "sp_defense", "stage_delta": 1, "retention_mode": "normal"}
			)
	_validate_single_payload_effect(
		content_index, errors,
		"obito_juubi_jinchuriki", label, "obito_yinyang_dun_guard_rule_mod",
		RuleModPayloadScript, "rule_mod",
		{
			"mod_kind": "incoming_action_final_mod", "mod_op": "mul", "value": 0.5, "scope": "self",
			"duration_mode": "turns", "duration": 1, "decrement_on": "turn_end",
			"stacking": "refresh", "priority": 10,
			"required_incoming_command_types": PackedStringArray(["skill", "ultimate"]),
		},
		"guard"
	)
	_validate_single_payload_effect(
		content_index, errors,
		"obito_juubi_jinchuriki", label, "obito_yinyang_dun_guard_stack_listener",
		ApplyEffectPayloadScript, "apply_effect",
		{"effect_definition_id": "obito_yinyang_dun_guard_stack_listener_state"},
		"listener_apply"
	)
	_validate_single_payload_effect(
		content_index, errors,
		"obito_juubi_jinchuriki", label, "obito_yinyang_dun_guard_stack_listener_state",
		ApplyEffectPayloadScript, "apply_effect",
		{"effect_definition_id": "obito_yinyang_zhili"},
		"listener_state"
	)

func _validate_qiudaoyu_contracts(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[obito_juubi_jinchuriki].qiudao_yu"
	_validate_single_payload_effect(
		content_index, errors,
		"obito_juubi_jinchuriki", label, "obito_qiudao_yu_clear_yinyang",
		RemoveEffectPayloadScript, "remove_effect",
		{"effect_definition_id": "obito_yinyang_zhili", "remove_mode": "all"}
	)

func _validate_ultimate_domain(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_skill_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.skill_contract("obito_juubi_jinchuriki", "obito_shiwei_weishouyu")]
	)
	var label := "formal[obito_juubi_jinchuriki].shiwei_weishouyu"
	var skill_definition = _require_skill(content_index, errors, label, "obito_shiwei_weishouyu")
	if skill_definition == null:
		return
	if skill_definition.damage_segments.size() != 2:
		errors.append("%s damage_segments size mismatch: expected 2 got %d" % [label, skill_definition.damage_segments.size()])
		return
	_validate_ultimate_segment(errors, label, skill_definition.damage_segments[0], 0, 2, 12, "dark", "special")
	_validate_ultimate_segment(errors, label, skill_definition.damage_segments[1], 1, 8, 12, "light", "special")

func _validate_ultimate_segment(
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
	var segment_label := "%s damage_segments[%d]" % [label, index]
	_expect_int(errors, "%s.repeat_count" % segment_label, segment.repeat_count, expected_repeat_count)
	_expect_int(errors, "%s.power" % segment_label, segment.power, expected_power)
	_expect_string(errors, "%s.combat_type_id" % segment_label, segment.combat_type_id, expected_combat_type_id)
	_expect_string(errors, "%s.damage_kind" % segment_label, segment.damage_kind, expected_damage_kind)
