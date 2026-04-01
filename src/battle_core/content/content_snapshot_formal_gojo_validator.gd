extends RefCounted
class_name ContentSnapshotFormalGojoValidator

const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

func validate(content_index, errors: Array) -> void:
	_validate_murasaki_burst(content_index, errors)
	_validate_domain_followup(content_index, errors)
	_validate_domain_buff_contract(content_index, errors)

func _validate_murasaki_burst(content_index, errors: Array) -> void:
	var label := "formal[gojo].murasaki_burst"
	var effect_definition = content_index.effects.get("gojo_murasaki_conditional_burst", null)
	if effect_definition == null:
		return
	_expect_packed_string_array(
		errors,
		"%s required_target_effects" % label,
		effect_definition.required_target_effects,
		PackedStringArray(["gojo_ao_mark", "gojo_aka_mark"])
	)
	if not bool(effect_definition.required_target_same_owner):
		errors.append("%s required_target_same_owner must be true" % label)
	var damage_payload = _extract_single_payload(
		errors,
		label,
		"gojo_murasaki_conditional_burst",
		effect_definition,
		DamagePayloadScript,
		"damage"
	)
	if damage_payload == null:
		return
	if not bool(damage_payload.use_formula):
		errors.append("%s damage payload must use formula" % label)
	if String(damage_payload.damage_kind) != "special":
		errors.append("%s damage_kind mismatch: expected special got %s" % [
			label,
			String(damage_payload.damage_kind),
		])
	if int(damage_payload.amount) != 32:
		errors.append("%s amount mismatch: expected 32 got %d" % [label, int(damage_payload.amount)])

func _validate_domain_followup(content_index, errors: Array) -> void:
	var label := "formal[gojo].domain_followup"
	var effect_definition = content_index.effects.get("gojo_apply_domain_field", null)
	if effect_definition == null:
		return
	var apply_field_payload = _extract_single_payload(
		errors,
		label,
		"gojo_apply_domain_field",
		effect_definition,
		ApplyFieldPayloadScript,
		"apply_field"
	)
	if apply_field_payload == null:
		return
	if String(apply_field_payload.field_definition_id) != "gojo_unlimited_void_field":
		errors.append("%s field_definition_id mismatch: expected gojo_unlimited_void_field got %s" % [
			label,
			String(apply_field_payload.field_definition_id),
		])
	_expect_packed_string_array(
		errors,
		"%s on_success_effect_ids" % label,
		apply_field_payload.on_success_effect_ids,
		PackedStringArray(["gojo_domain_action_lock"])
	)

func _validate_domain_buff_contract(content_index, errors: Array) -> void:
	var label := "formal[gojo].domain_buff_contract"
	var field_definition = content_index.fields.get("gojo_unlimited_void_field", null)
	if field_definition != null:
		_expect_packed_string_array(
			errors,
			"%s field.effect_ids" % label,
			field_definition.effect_ids,
			PackedStringArray(["gojo_domain_cast_buff"])
		)
		_expect_packed_string_array(
			errors,
			"%s field.on_expire_effect_ids" % label,
			field_definition.on_expire_effect_ids,
			PackedStringArray(["gojo_domain_buff_remove"])
		)
		_expect_packed_string_array(
			errors,
			"%s field.on_break_effect_ids" % label,
			field_definition.on_break_effect_ids,
			PackedStringArray(["gojo_domain_buff_remove"])
		)
	_validate_stat_mod_effect(content_index, errors, label, "gojo_domain_cast_buff", "sp_attack", 1)
	_validate_stat_mod_effect(content_index, errors, label, "gojo_domain_buff_remove", "sp_attack", -1)

func _validate_stat_mod_effect(
	content_index,
	errors: Array,
	label: String,
	effect_id: String,
	expected_stat_name: String,
	expected_stage_delta: int
) -> void:
	var effect_definition = content_index.effects.get(effect_id, null)
	if effect_definition == null:
		return
	var stat_mod_payload = _extract_single_payload(
		errors,
		label,
		effect_id,
		effect_definition,
		StatModPayloadScript,
		"stat_mod"
	)
	if stat_mod_payload == null:
		return
	if String(stat_mod_payload.stat_name) != expected_stat_name:
		errors.append("%s effect[%s].stat_name mismatch: expected %s got %s" % [
			label,
			effect_id,
			expected_stat_name,
			String(stat_mod_payload.stat_name),
		])
	if int(stat_mod_payload.stage_delta) != expected_stage_delta:
		errors.append("%s effect[%s].stage_delta mismatch: expected %d got %d" % [
			label,
			effect_id,
			expected_stage_delta,
			int(stat_mod_payload.stage_delta),
		])

func _extract_single_payload(
	errors: Array,
	label: String,
	effect_id: String,
	effect_definition,
	payload_script,
	payload_name: String
):
	var matched_payloads: Array = []
	for payload in effect_definition.payloads:
		if payload != null and payload.get_script() == payload_script:
			matched_payloads.append(payload)
	if matched_payloads.size() != 1:
		errors.append("%s effect[%s] must define exactly one %s payload, got %d" % [
			label,
			effect_id,
			payload_name,
			matched_payloads.size(),
		])
		return null
	return matched_payloads[0]

func _expect_packed_string_array(errors: Array, label: String, actual: PackedStringArray, expected: PackedStringArray) -> void:
	if actual == expected:
		return
	errors.append("%s mismatch: expected %s got %s" % [label, var_to_str(expected), var_to_str(actual)])
