extends RefCounted
class_name ContentSnapshotFormalObitoEffectContractHelper

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_character_contract_helper.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate_heal_block_contracts(validator, content_index, errors: Array) -> void:
	var label := "formal[obito].heal_block"
	var apply_effect = validator._require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_apply")
	if apply_effect != null:
		_helper.validate_effect_contracts(validator, content_index, errors, [{
			"label": "%s apply" % label,
			"effect_id": "obito_qiudao_jiaotu_heal_block_apply",
			"fields": {
				"scope": "target",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_hit"]),
			},
		}])
		var apply_payload = validator._extract_single_payload(errors, label, "obito_qiudao_jiaotu_heal_block_apply", apply_effect, ApplyEffectPayloadScript, "apply_effect")
		validator._expect_payload_shape(errors, "%s apply" % label, apply_payload, {"effect_definition_id": "obito_qiudao_jiaotu_heal_block_mark"})
	var mark_effect = validator._require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_mark")
	if mark_effect != null:
		_helper.validate_effect_contracts(validator, content_index, errors, [{
			"label": "%s mark" % label,
			"effect_id": "obito_qiudao_jiaotu_heal_block_mark",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 2,
				"decrement_on": "turn_end",
				"stacking": "refresh",
				"trigger_names": PackedStringArray(),
				"persists_on_switch": true,
			},
		}])
	var rule_mod_effect = validator._require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_rule_mod")
	if rule_mod_effect == null:
		return
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": "%s rule_mod" % label,
		"effect_id": "obito_qiudao_jiaotu_heal_block_rule_mod",
		"fields": {
			"scope": "target",
			"duration_mode": "turns",
			"duration": 2,
			"decrement_on": "turn_end",
			"stacking": "none",
			"trigger_names": PackedStringArray(["on_hit"]),
			"persists_on_switch": true,
		},
	}])
	var payload = validator._extract_single_payload(errors, label, "obito_qiudao_jiaotu_heal_block_rule_mod", rule_mod_effect, RuleModPayloadScript, "rule_mod")
	validator._expect_payload_shape(
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

func validate_yinyang_dun_contracts(validator, content_index, errors: Array) -> void:
	var label := "formal[obito].yinyang_dun"
	var boost_effect = validator._require_effect(content_index, errors, label, "obito_yinyang_dun_boost_and_charge")
	if boost_effect != null:
		_helper.validate_effect_contracts(validator, content_index, errors, [{
			"label": "%s boost" % label,
			"effect_id": "obito_yinyang_dun_boost_and_charge",
			"fields": {
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_cast"]),
			},
		}])
		if boost_effect.payloads.size() != 3:
			errors.append("%s boost payload count mismatch: expected 3 got %d" % [label, boost_effect.payloads.size()])
		else:
			_expect_boost_payloads(validator, errors, label, boost_effect.payloads)
	var guard_effect = validator._require_effect(content_index, errors, label, "obito_yinyang_dun_guard_rule_mod")
	if guard_effect != null:
		_helper.validate_effect_contracts(validator, content_index, errors, [{
			"label": "%s guard" % label,
			"effect_id": "obito_yinyang_dun_guard_rule_mod",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 1,
				"decrement_on": "turn_end",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_cast"]),
			},
		}])
		var guard_payload = validator._extract_single_payload(errors, label, "obito_yinyang_dun_guard_rule_mod", guard_effect, RuleModPayloadScript, "rule_mod")
		validator._expect_payload_shape(errors, "%s guard.payload" % label, guard_payload, {
			"mod_kind": "incoming_action_final_mod", "mod_op": "mul", "value": 0.5, "scope": "self",
			"duration_mode": "turns", "duration": 1, "decrement_on": "turn_end",
			"stacking": "refresh", "priority": 10,
			"required_incoming_command_types": PackedStringArray(["skill", "ultimate"]),
		})
	var listener_apply_effect = validator._require_effect(content_index, errors, label, "obito_yinyang_dun_guard_stack_listener")
	if listener_apply_effect != null:
		_helper.validate_effect_contracts(validator, content_index, errors, [{
			"label": "%s listener_apply" % label,
			"effect_id": "obito_yinyang_dun_guard_stack_listener",
			"fields": {
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_cast"]),
			},
		}])
		var listener_apply_payload = validator._extract_single_payload(errors, label, "obito_yinyang_dun_guard_stack_listener", listener_apply_effect, ApplyEffectPayloadScript, "apply_effect")
		validator._expect_payload_shape(errors, "%s listener_apply.payload" % label, listener_apply_payload, {"effect_definition_id": "obito_yinyang_dun_guard_stack_listener_state"})
	var listener_state_effect = validator._require_effect(content_index, errors, label, "obito_yinyang_dun_guard_stack_listener_state")
	if listener_state_effect == null:
		return
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": "%s listener_state" % label,
		"effect_id": "obito_yinyang_dun_guard_stack_listener_state",
		"fields": {
			"scope": "self",
			"duration_mode": "turns",
			"duration": 1,
			"decrement_on": "turn_end",
			"stacking": "none",
			"trigger_names": PackedStringArray(["on_receive_action_damage_segment"]),
			"required_incoming_command_types": PackedStringArray(["skill", "ultimate"]),
			"persists_on_switch": false,
		},
	}])
	var listener_state_payload = validator._extract_single_payload(errors, label, "obito_yinyang_dun_guard_stack_listener_state", listener_state_effect, ApplyEffectPayloadScript, "apply_effect")
	validator._expect_payload_shape(errors, "%s listener_state.payload" % label, listener_state_payload, {"effect_definition_id": "obito_yinyang_zhili"})

func _expect_boost_payloads(validator, errors: Array, label: String, payloads: Array) -> void:
	var apply_payload = payloads[0]
	var defense_payload = payloads[1]
	var sp_defense_payload = payloads[2]
	if apply_payload == null or apply_payload.get_script() != ApplyEffectPayloadScript:
		errors.append("%s boost payload[0] must be apply_effect" % label)
	else:
		validator._expect_payload_shape(errors, "%s boost.payload[0]" % label, apply_payload, {"effect_definition_id": "obito_yinyang_zhili"})
	if defense_payload == null or defense_payload.get_script() != StatModPayloadScript:
		errors.append("%s boost payload[1] must be stat_mod" % label)
	else:
		validator._expect_payload_shape(errors, "%s boost.payload[1]" % label, defense_payload, {"stat_name": "defense", "stage_delta": 1, "retention_mode": "normal"})
	if sp_defense_payload == null or sp_defense_payload.get_script() != StatModPayloadScript:
		errors.append("%s boost payload[2] must be stat_mod" % label)
	else:
		validator._expect_payload_shape(errors, "%s boost.payload[2]" % label, sp_defense_payload, {"stat_name": "sp_defense", "stage_delta": 1, "retention_mode": "normal"})
