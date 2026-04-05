extends RefCounted
class_name ContentSnapshotFormalObitoEffectContractHelper

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

func validate_heal_block_contracts(validator, content_index, errors: Array) -> void:
	var label := "formal[obito].heal_block"
	var apply_effect = validator._require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_apply")
	if apply_effect != null:
		validator._expect_string(errors, "%s apply.scope" % label, apply_effect.scope, "target")
		validator._expect_string(errors, "%s apply.duration_mode" % label, apply_effect.duration_mode, "permanent")
		validator._expect_string(errors, "%s apply.stacking" % label, apply_effect.stacking, "none")
		validator._expect_packed_string_array(errors, "%s apply.trigger_names" % label, apply_effect.trigger_names, PackedStringArray(["on_hit"]))
		var apply_payload = validator._extract_single_payload(errors, label, "obito_qiudao_jiaotu_heal_block_apply", apply_effect, ApplyEffectPayloadScript, "apply_effect")
		validator._expect_payload_shape(errors, "%s apply" % label, apply_payload, {"effect_definition_id": "obito_qiudao_jiaotu_heal_block_mark"})
	var mark_effect = validator._require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_mark")
	if mark_effect != null:
		validator._expect_string(errors, "%s mark.scope" % label, mark_effect.scope, "self")
		validator._expect_string(errors, "%s mark.duration_mode" % label, mark_effect.duration_mode, "turns")
		validator._expect_int(errors, "%s mark.duration" % label, mark_effect.duration, 2)
		validator._expect_string(errors, "%s mark.decrement_on" % label, mark_effect.decrement_on, "turn_end")
		validator._expect_string(errors, "%s mark.stacking" % label, mark_effect.stacking, "refresh")
		validator._expect_packed_string_array(errors, "%s mark.trigger_names" % label, mark_effect.trigger_names, PackedStringArray())
		validator._expect_bool(errors, "%s mark.persists_on_switch" % label, mark_effect.persists_on_switch, true)
	var rule_mod_effect = validator._require_effect(content_index, errors, label, "obito_qiudao_jiaotu_heal_block_rule_mod")
	if rule_mod_effect == null:
		return
	validator._expect_string(errors, "%s rule_mod.scope" % label, rule_mod_effect.scope, "target")
	validator._expect_string(errors, "%s rule_mod.duration_mode" % label, rule_mod_effect.duration_mode, "turns")
	validator._expect_int(errors, "%s rule_mod.duration" % label, rule_mod_effect.duration, 2)
	validator._expect_string(errors, "%s rule_mod.decrement_on" % label, rule_mod_effect.decrement_on, "turn_end")
	validator._expect_string(errors, "%s rule_mod.stacking" % label, rule_mod_effect.stacking, "none")
	validator._expect_packed_string_array(errors, "%s rule_mod.trigger_names" % label, rule_mod_effect.trigger_names, PackedStringArray(["on_hit"]))
	validator._expect_bool(errors, "%s rule_mod.persists_on_switch" % label, rule_mod_effect.persists_on_switch, true)
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
		validator._expect_string(errors, "%s boost.scope" % label, boost_effect.scope, "self")
		validator._expect_string(errors, "%s boost.duration_mode" % label, boost_effect.duration_mode, "permanent")
		validator._expect_string(errors, "%s boost.stacking" % label, boost_effect.stacking, "none")
		validator._expect_packed_string_array(errors, "%s boost.trigger_names" % label, boost_effect.trigger_names, PackedStringArray(["on_cast"]))
		if boost_effect.payloads.size() != 3:
			errors.append("%s boost payload count mismatch: expected 3 got %d" % [label, boost_effect.payloads.size()])
		else:
			_expect_boost_payloads(validator, errors, label, boost_effect.payloads)
	var guard_effect = validator._require_effect(content_index, errors, label, "obito_yinyang_dun_guard_rule_mod")
	if guard_effect != null:
		validator._expect_string(errors, "%s guard.scope" % label, guard_effect.scope, "self")
		validator._expect_string(errors, "%s guard.duration_mode" % label, guard_effect.duration_mode, "turns")
		validator._expect_int(errors, "%s guard.duration" % label, guard_effect.duration, 1)
		validator._expect_string(errors, "%s guard.decrement_on" % label, guard_effect.decrement_on, "turn_end")
		validator._expect_string(errors, "%s guard.stacking" % label, guard_effect.stacking, "none")
		validator._expect_packed_string_array(errors, "%s guard.trigger_names" % label, guard_effect.trigger_names, PackedStringArray(["on_cast"]))
		var guard_payload = validator._extract_single_payload(errors, label, "obito_yinyang_dun_guard_rule_mod", guard_effect, RuleModPayloadScript, "rule_mod")
		validator._expect_payload_shape(errors, "%s guard.payload" % label, guard_payload, {
			"mod_kind": "incoming_action_final_mod", "mod_op": "mul", "value": 0.5, "scope": "self",
			"duration_mode": "turns", "duration": 1, "decrement_on": "turn_end",
			"stacking": "refresh", "priority": 10,
			"required_incoming_command_types": PackedStringArray(["skill", "ultimate"]),
		})
	var listener_apply_effect = validator._require_effect(content_index, errors, label, "obito_yinyang_dun_guard_stack_listener")
	if listener_apply_effect != null:
		validator._expect_string(errors, "%s listener_apply.scope" % label, listener_apply_effect.scope, "self")
		validator._expect_string(errors, "%s listener_apply.duration_mode" % label, listener_apply_effect.duration_mode, "permanent")
		validator._expect_string(errors, "%s listener_apply.stacking" % label, listener_apply_effect.stacking, "none")
		validator._expect_packed_string_array(errors, "%s listener_apply.trigger_names" % label, listener_apply_effect.trigger_names, PackedStringArray(["on_cast"]))
		var listener_apply_payload = validator._extract_single_payload(errors, label, "obito_yinyang_dun_guard_stack_listener", listener_apply_effect, ApplyEffectPayloadScript, "apply_effect")
		validator._expect_payload_shape(errors, "%s listener_apply.payload" % label, listener_apply_payload, {"effect_definition_id": "obito_yinyang_dun_guard_stack_listener_state"})
	var listener_state_effect = validator._require_effect(content_index, errors, label, "obito_yinyang_dun_guard_stack_listener_state")
	if listener_state_effect == null:
		return
	validator._expect_string(errors, "%s listener_state.scope" % label, listener_state_effect.scope, "self")
	validator._expect_string(errors, "%s listener_state.duration_mode" % label, listener_state_effect.duration_mode, "turns")
	validator._expect_int(errors, "%s listener_state.duration" % label, listener_state_effect.duration, 1)
	validator._expect_string(errors, "%s listener_state.decrement_on" % label, listener_state_effect.decrement_on, "turn_end")
	validator._expect_string(errors, "%s listener_state.stacking" % label, listener_state_effect.stacking, "none")
	validator._expect_packed_string_array(errors, "%s listener_state.trigger_names" % label, listener_state_effect.trigger_names, PackedStringArray(["on_receive_action_damage_segment"]))
	validator._expect_bool(errors, "%s listener_state.persists_on_switch" % label, listener_state_effect.persists_on_switch, false)
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
