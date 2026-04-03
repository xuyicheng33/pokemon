extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalKashimoValidator

const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

func validate(content_index, errors: Array) -> void:
	_validate_core_skill_contract(content_index, errors)
	_validate_feedback_strike(content_index, errors)
	_validate_charge_separation(content_index, errors)
	_validate_amber_contract(content_index, errors)

func _validate_core_skill_contract(content_index, errors: Array) -> void:
	var raiken_label := "formal[kashimo].raiken"
	var raiken_definition = _require_skill(content_index, errors, raiken_label, "kashimo_raiken")
	if raiken_definition != null:
		_expect_string(errors, "%s damage_kind" % raiken_label, raiken_definition.damage_kind, "physical")
		_expect_int(errors, "%s power" % raiken_label, raiken_definition.power, 45)
		_expect_int(errors, "%s priority" % raiken_label, raiken_definition.priority, 1)
		_expect_string(errors, "%s combat_type_id" % raiken_label, raiken_definition.combat_type_id, "thunder")
		_expect_packed_string_array(errors, "%s effects_on_hit_ids" % raiken_label, raiken_definition.effects_on_hit_ids, PackedStringArray(["kashimo_apply_negative_charge"]))
	var charge_label := "formal[kashimo].charge"
	var charge_definition = _require_skill(content_index, errors, charge_label, "kashimo_charge")
	if charge_definition != null:
		_expect_int(errors, "%s mp_cost" % charge_label, charge_definition.mp_cost, 8)
		_expect_string(errors, "%s targeting" % charge_label, charge_definition.targeting, "self")
		_expect_packed_string_array(errors, "%s effects_on_cast_ids" % charge_label, charge_definition.effects_on_cast_ids, PackedStringArray(["kashimo_apply_positive_charge"]))

func _validate_feedback_strike(content_index, errors: Array) -> void:
	var label := "formal[kashimo].feedback_strike"
	var skill_definition = _require_skill(content_index, errors, label, "kashimo_feedback_strike")
	if skill_definition == null:
		return
	if String(skill_definition.power_bonus_source) != "effect_stack_sum":
		errors.append("%s power_bonus_source mismatch: expected effect_stack_sum got %s" % [
			label,
			String(skill_definition.power_bonus_source),
		])
	_expect_packed_string_array(
		errors,
		"%s power_bonus_self_effect_ids" % label,
		skill_definition.power_bonus_self_effect_ids,
		PackedStringArray(["kashimo_positive_charge_mark"])
	)
	_expect_packed_string_array(
		errors,
		"%s power_bonus_target_effect_ids" % label,
		skill_definition.power_bonus_target_effect_ids,
		PackedStringArray(["kashimo_negative_charge_mark"])
	)
	if int(skill_definition.power_bonus_per_stack) != 12:
		errors.append("%s power_bonus_per_stack mismatch: expected 12 got %d" % [
			label,
			int(skill_definition.power_bonus_per_stack),
		])
	_expect_packed_string_array(
		errors,
		"%s effects_on_hit_ids" % label,
		skill_definition.effects_on_hit_ids,
		PackedStringArray(["kashimo_consume_positive_charges", "kashimo_consume_negative_charges"])
	)

func _validate_charge_separation(content_index, errors: Array) -> void:
	_validate_thunder_resist(content_index, errors)
	_validate_water_leak_counter(content_index, errors)

func _validate_thunder_resist(content_index, errors: Array) -> void:
	var label := "formal[kashimo].thunder_resist"
	var effect_definition = _require_effect(content_index, errors, label, "kashimo_thunder_resist")
	if effect_definition == null:
		return
	var payload = _extract_single_payload(
		errors,
		label,
		"kashimo_thunder_resist",
		effect_definition,
		RuleModPayloadScript,
		"rule_mod"
	)
	if payload == null:
		return
	if String(payload.mod_kind) != "incoming_action_final_mod":
		errors.append("%s mod_kind mismatch: expected incoming_action_final_mod got %s" % [
			label,
			String(payload.mod_kind),
		])
	if String(payload.mod_op) != "mul":
		errors.append("%s mod_op mismatch: expected mul got %s" % [label, String(payload.mod_op)])
	if float(payload.value) != 0.5:
		errors.append("%s value mismatch: expected 0.5 got %s" % [label, var_to_str(payload.value)])
	_expect_packed_string_array(
		errors,
		"%s required_incoming_command_types" % label,
		payload.required_incoming_command_types,
		PackedStringArray(["skill", "ultimate"])
	)
	_expect_packed_string_array(
		errors,
		"%s required_incoming_combat_type_ids" % label,
		payload.required_incoming_combat_type_ids,
		PackedStringArray(["thunder"])
	)

func _validate_water_leak_counter(content_index, errors: Array) -> void:
	var label := "formal[kashimo].water_leak_counter"
	var effect_definition = _require_effect(content_index, errors, label, "kashimo_water_leak_counter_listener")
	if effect_definition == null:
		return
	var payload = _extract_single_payload(
		errors,
		label,
		"kashimo_water_leak_counter_listener",
		effect_definition,
		DamagePayloadScript,
		"damage"
	)
	if payload == null:
		return
	if String(effect_definition.scope) != "action_actor":
		errors.append("%s scope mismatch: expected action_actor got %s" % [
			label,
			String(effect_definition.scope),
		])
	_expect_packed_string_array(
		errors,
		"%s trigger_names" % label,
		effect_definition.trigger_names,
		PackedStringArray(["on_receive_action_hit"])
	)
	_expect_packed_string_array(
		errors,
		"%s required_incoming_command_types" % label,
		effect_definition.required_incoming_command_types,
		PackedStringArray(["skill", "ultimate"])
	)
	_expect_packed_string_array(
		errors,
		"%s required_incoming_combat_type_ids" % label,
		effect_definition.required_incoming_combat_type_ids,
		PackedStringArray(["water"])
	)
	if int(payload.amount) != 15:
		errors.append("%s amount mismatch: expected 15 got %d" % [label, int(payload.amount)])
	if String(payload.combat_type_id) != "poison":
		errors.append("%s combat_type_id mismatch: expected poison got %s" % [
			label,
			String(payload.combat_type_id),
		])

func _validate_amber_contract(content_index, errors: Array) -> void:
	var label := "formal[kashimo].amber_contract"
	var unit_definition = _require_unit(content_index, errors, label, "kashimo_hajime")
	if unit_definition != null:
		if String(unit_definition.ultimate_skill_id) != "kashimo_phantom_beast_amber":
			errors.append("%s unit.ultimate_skill_id mismatch: expected kashimo_phantom_beast_amber got %s" % [
				label,
				String(unit_definition.ultimate_skill_id),
			])
		if int(unit_definition.ultimate_points_required) != 3 or int(unit_definition.ultimate_points_cap) != 3 or int(unit_definition.ultimate_point_gain_on_regular_skill_cast) != 1:
			errors.append("%s unit ultimate points mismatch: expected 3/3/1 got %d/%d/%d" % [
				label,
				int(unit_definition.ultimate_points_required),
				int(unit_definition.ultimate_points_cap),
				int(unit_definition.ultimate_point_gain_on_regular_skill_cast),
			])
	var amber_effect = _require_effect(content_index, errors, label, "kashimo_amber_self_transform")
	var amber_bleed = _require_effect(content_index, errors, label, "kashimo_amber_bleed")
	if amber_effect == null or amber_bleed == null:
		return
	var stat_payloads := _extract_stat_payloads(amber_effect)
	_expect_persistent_stat_mod(errors, label, stat_payloads, "attack", 2)
	_expect_persistent_stat_mod(errors, label, stat_payloads, "sp_attack", 2)
	_expect_persistent_stat_mod(errors, label, stat_payloads, "speed", 1)
	var amber_lock = _extract_rule_mod_by_kind(amber_effect, "action_legality")
	if amber_lock == null:
		errors.append("%s missing action_legality rule_mod payload" % label)
	else:
		if String(amber_lock.mod_op) != "deny" or String(amber_lock.value) != "ultimate":
			errors.append("%s amber ultimate lock mismatch: expected deny ultimate got %s %s" % [
				label,
				String(amber_lock.mod_op),
				String(amber_lock.value),
			])
		if not bool(amber_lock.persists_on_switch):
			errors.append("%s amber ultimate lock must persist_on_switch=true" % label)
	if not bool(amber_bleed.persists_on_switch):
		errors.append("%s amber bleed must persist_on_switch=true" % label)

func _extract_stat_payloads(effect_definition) -> Array:
	var matched_payloads: Array = []
	for payload in effect_definition.payloads:
		if payload is StatModPayloadScript:
			matched_payloads.append(payload)
	return matched_payloads

func _extract_rule_mod_by_kind(effect_definition, mod_kind: String):
	for payload in effect_definition.payloads:
		if payload is RuleModPayloadScript and String(payload.mod_kind) == mod_kind:
			return payload
	return null

func _expect_persistent_stat_mod(errors: Array, label: String, stat_payloads: Array, stat_name: String, stage_delta: int) -> void:
	for payload in stat_payloads:
		if String(payload.stat_name) != stat_name:
			continue
		if int(payload.stage_delta) != stage_delta:
			errors.append("%s stat[%s].stage_delta mismatch: expected %d got %d" % [
				label,
				stat_name,
				stage_delta,
				int(payload.stage_delta),
			])
		if String(payload.retention_mode) != "persist_on_switch":
			errors.append("%s stat[%s].retention_mode mismatch: expected persist_on_switch got %s" % [
				label,
				stat_name,
				String(payload.retention_mode),
			])
		return
	errors.append("%s missing stat_mod payload for %s" % [label, stat_name])
