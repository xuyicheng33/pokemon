extends RefCounted
class_name ContentSnapshotFormalGojoDomainContracts

const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

func validate(validator, content_index, errors: Array) -> void:
	_validate_domain_followup(validator, content_index, errors)
	_validate_domain_buff_contract(validator, content_index, errors)

func _validate_domain_followup(validator, content_index, errors: Array) -> void:
	var label := "formal[gojo].domain_followup"
	var effect_definition = validator._require_effect(content_index, errors, label, "gojo_apply_domain_field")
	if effect_definition == null:
		return
	var apply_field_payload = validator._extract_single_payload(
		errors,
		label,
		"gojo_apply_domain_field",
		effect_definition,
		ApplyFieldPayloadScript,
		"apply_field"
	)
	if apply_field_payload == null:
		return
	validator._expect_string(errors, "%s scope" % label, effect_definition.scope, "field")
	validator._expect_string(errors, "%s duration_mode" % label, effect_definition.duration_mode, "turns")
	validator._expect_int(errors, "%s duration" % label, effect_definition.duration, 3)
	validator._expect_string(errors, "%s decrement_on" % label, effect_definition.decrement_on, "turn_end")
	validator._expect_string(errors, "%s stacking" % label, effect_definition.stacking, "replace")
	if String(apply_field_payload.field_definition_id) != "gojo_unlimited_void_field":
		errors.append("%s field_definition_id mismatch: expected gojo_unlimited_void_field got %s" % [
			label,
			String(apply_field_payload.field_definition_id),
		])
	validator._expect_packed_string_array(
		errors,
		"%s trigger_names" % label,
		effect_definition.trigger_names,
		PackedStringArray(["on_hit"])
	)
	validator._expect_packed_string_array(
		errors,
		"%s on_success_effect_ids" % label,
		apply_field_payload.on_success_effect_ids,
		PackedStringArray(["gojo_domain_action_lock"])
	)

func _validate_domain_buff_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[gojo].domain_buff_contract"
	var field_definition = validator._require_field(content_index, errors, label, "gojo_unlimited_void_field")
	if field_definition != null:
		validator._expect_string(errors, "%s field.field_kind" % label, field_definition.field_kind, "domain")
		validator._expect_packed_string_array(
			errors,
			"%s field.effect_ids" % label,
			field_definition.effect_ids,
			PackedStringArray(["gojo_domain_cast_buff"])
		)
		validator._expect_packed_string_array(
			errors,
			"%s field.on_expire_effect_ids" % label,
			field_definition.on_expire_effect_ids,
			PackedStringArray(["gojo_domain_buff_remove"])
		)
		validator._expect_packed_string_array(
			errors,
			"%s field.on_break_effect_ids" % label,
			field_definition.on_break_effect_ids,
			PackedStringArray(["gojo_domain_buff_remove"])
		)
		validator._expect_int(errors, "%s field.creator_accuracy_override" % label, field_definition.creator_accuracy_override, 100)
	var action_lock_effect = validator._require_effect(content_index, errors, label, "gojo_domain_action_lock")
	if action_lock_effect != null:
		validator._expect_packed_string_array(
			errors,
			"%s action_lock.trigger_names" % label,
			action_lock_effect.trigger_names,
			PackedStringArray(["field_apply_success"])
		)
		var action_lock_payload = validator._extract_single_payload(
			errors,
			label,
			"gojo_domain_action_lock",
			action_lock_effect,
			RuleModPayloadScript,
			"rule_mod"
		)
		validator._expect_payload_shape(
			errors,
			"%s action_lock" % label,
			action_lock_payload,
			{
				"mod_kind": "action_legality",
				"mod_op": "deny",
				"value": "all",
				"duration_mode": "turns",
				"duration": 1,
				"decrement_on": "turn_end",
			}
		)
	_validate_stat_mod_effect(validator, content_index, errors, label, "gojo_domain_cast_buff", "sp_attack", 1, PackedStringArray(["field_apply"]))
	_validate_stat_mod_effect(validator, content_index, errors, label, "gojo_domain_buff_remove", "sp_attack", -1, PackedStringArray(["field_break", "field_expire"]))

func _validate_stat_mod_effect(
	validator,
	content_index,
	errors: Array,
	label: String,
	effect_id: String,
	expected_stat_name: String,
	expected_stage_delta: int,
	expected_trigger_names: PackedStringArray
) -> void:
	var effect_definition = validator._require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s effect[%s].scope" % [label, effect_id], effect_definition.scope, "self")
	validator._expect_string(errors, "%s effect[%s].duration_mode" % [label, effect_id], effect_definition.duration_mode, "permanent")
	validator._expect_string(errors, "%s effect[%s].stacking" % [label, effect_id], effect_definition.stacking, "none")
	validator._expect_packed_string_array(errors, "%s effect[%s].trigger_names" % [label, effect_id], effect_definition.trigger_names, expected_trigger_names)
	var stat_mod_payload = validator._extract_single_payload(
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
