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
	var effect_definition = _require_effect(content_index, errors, label, "obito_xianren_zhili_heal")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_xianren_zhili_heal", "%s effect" % label)]
	)
	var heal_payload = _extract_single_payload(
		errors,
		label,
		"obito_xianren_zhili_heal",
		effect_definition,
		HealPayloadScript,
		"heal"
	)
	_expect_payload_shape(
		errors,
		"%s effect" % label,
		heal_payload,
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
	var apply_effect = _require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_apply")
	if apply_effect != null:
		_helper.validate_effect_contracts(
			self,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_jiaotu_heal_block_apply", "%s apply" % label)]
		)
		var apply_payload = _extract_single_payload(errors, label, "obito_qiudao_jiaotu_heal_block_apply", apply_effect, ApplyEffectPayloadScript, "apply_effect")
		_expect_payload_shape(errors, "%s apply" % label, apply_payload, {"effect_definition_id": "obito_qiudao_jiaotu_heal_block_mark"})
	var mark_effect = _require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_mark")
	if mark_effect != null:
		_helper.validate_effect_contracts(
			self,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_jiaotu_heal_block_mark", "%s mark" % label)]
		)
	var rule_mod_effect = _require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_rule_mod")
	if rule_mod_effect == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_jiaotu_heal_block_rule_mod", "%s rule_mod" % label)]
	)
	var payload = _extract_single_payload(errors, label, "obito_qiudao_jiaotu_heal_block_rule_mod", rule_mod_effect, RuleModPayloadScript, "rule_mod")
	_expect_payload_shape(
		errors,
		"%s payload" % label,
		payload,
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
		}
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
			_expect_boost_payloads(errors, label, boost_effect.payloads)
	var guard_effect = _require_effect(content_index, errors, label, "obito_yinyang_dun_guard_rule_mod")
	if guard_effect != null:
		_helper.validate_effect_contracts(
			self,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_dun_guard_rule_mod", "%s guard" % label)]
		)
		var guard_payload = _extract_single_payload(errors, label, "obito_yinyang_dun_guard_rule_mod", guard_effect, RuleModPayloadScript, "rule_mod")
		_expect_payload_shape(errors, "%s guard.payload" % label, guard_payload, {
			"mod_kind": "incoming_action_final_mod", "mod_op": "mul", "value": 0.5, "scope": "self",
			"duration_mode": "turns", "duration": 1, "decrement_on": "turn_end",
			"stacking": "refresh", "priority": 10,
			"required_incoming_command_types": PackedStringArray(["skill", "ultimate"]),
		})
	var listener_apply_effect = _require_effect(content_index, errors, label, "obito_yinyang_dun_guard_stack_listener")
	if listener_apply_effect != null:
		_helper.validate_effect_contracts(
			self,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_dun_guard_stack_listener", "%s listener_apply" % label)]
		)
		var listener_apply_payload = _extract_single_payload(errors, label, "obito_yinyang_dun_guard_stack_listener", listener_apply_effect, ApplyEffectPayloadScript, "apply_effect")
		_expect_payload_shape(errors, "%s listener_apply.payload" % label, listener_apply_payload, {"effect_definition_id": "obito_yinyang_dun_guard_stack_listener_state"})
	var listener_state_effect = _require_effect(content_index, errors, label, "obito_yinyang_dun_guard_stack_listener_state")
	if listener_state_effect == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_dun_guard_stack_listener_state", "%s listener_state" % label)]
	)
	var listener_state_payload = _extract_single_payload(errors, label, "obito_yinyang_dun_guard_stack_listener_state", listener_state_effect, ApplyEffectPayloadScript, "apply_effect")
	_expect_payload_shape(errors, "%s listener_state.payload" % label, listener_state_payload, {"effect_definition_id": "obito_yinyang_zhili"})

func _expect_boost_payloads(errors: Array, label: String, payloads: Array) -> void:
	var apply_payload = payloads[0]
	var defense_payload = payloads[1]
	var sp_defense_payload = payloads[2]
	if apply_payload == null or apply_payload.get_script() != ApplyEffectPayloadScript:
		errors.append("%s boost payload[0] must be apply_effect" % label)
	else:
		_expect_payload_shape(errors, "%s boost.payload[0]" % label, apply_payload, {"effect_definition_id": "obito_yinyang_zhili"})
	if defense_payload == null or defense_payload.get_script() != StatModPayloadScript:
		errors.append("%s boost payload[1] must be stat_mod" % label)
	else:
		_expect_payload_shape(errors, "%s boost.payload[1]" % label, defense_payload, {"stat_name": "defense", "stage_delta": 1, "retention_mode": "normal"})
	if sp_defense_payload == null or sp_defense_payload.get_script() != StatModPayloadScript:
		errors.append("%s boost payload[2] must be stat_mod" % label)
	else:
		_expect_payload_shape(errors, "%s boost.payload[2]" % label, sp_defense_payload, {"stat_name": "sp_defense", "stage_delta": 1, "retention_mode": "normal"})

func _validate_qiudaoyu_contracts(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[obito_juubi_jinchuriki].qiudao_yu"
	var clear_effect = _require_effect(content_index, errors, label, "obito_qiudao_yu_clear_yinyang")
	if clear_effect == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_yu_clear_yinyang", "%s clear" % label)]
	)
	var clear_payload = _extract_single_payload(
		errors,
		label,
		"obito_qiudao_yu_clear_yinyang",
		clear_effect,
		RemoveEffectPayloadScript,
		"remove_effect"
	)
	_expect_payload_shape(
		errors,
		"%s clear.payload" % label,
		clear_payload,
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
