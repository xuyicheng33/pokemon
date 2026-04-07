extends RefCounted
class_name ContentSnapshotFormalSukunaContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate_unit_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_unit_contract_descriptor(
		validator,
		content_index,
		errors,
		FormalCharacterBaselinesScript.unit_contract("sukuna")
	)

func validate_core_skill_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(
		validator,
		content_index,
		errors,
		FormalCharacterBaselinesScript.skill_contracts(
			"sukuna",
			PackedStringArray([
				"sukuna_kai",
				"sukuna_hatsu",
				"sukuna_hiraku",
				"sukuna_reverse_ritual",
			])
		)
	)

func validate_kamado_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[sukuna].kamado"
	var apply_effect = validator._require_effect(content_index, errors, label, "sukuna_apply_kamado")
	if apply_effect != null:
		var apply_payload = validator._extract_single_payload(errors, label, "sukuna_apply_kamado", apply_effect, ApplyEffectPayloadScript, "apply_effect")
		validator._expect_payload_shape(errors, "%s apply" % label, apply_payload, {"effect_definition_id": "sukuna_kamado_mark"})
	var marker_effect = validator._require_effect(content_index, errors, label, "sukuna_kamado_mark")
	if marker_effect != null:
		_helper.validate_effect_contracts(
			validator,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("sukuna", "sukuna_kamado_mark", "%s mark" % label)]
		)

func validate_teach_love_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[sukuna].teach_love"
	_helper.validate_passive_skill_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.passive_contract("sukuna", "sukuna_teach_love", "%s passive" % label)]
	)
	var effect_definition = validator._require_effect(content_index, errors, label, "sukuna_refresh_love_regen")
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s effect stacking" % label, effect_definition.stacking, "none")
	var payload = validator._extract_single_payload(errors, label, "sukuna_refresh_love_regen", effect_definition, RuleModPayloadScript, "rule_mod")
	validator._expect_payload_shape(
		errors,
		"%s effect" % label,
		payload,
		{
			"mod_kind": "mp_regen",
			"mod_op": "add",
			"duration_mode": "permanent",
			"decrement_on": "turn_start",
			"stacking": "replace",
			"dynamic_value_formula": "matchup_bst_gap_band",
			"dynamic_value_default": 0.0,
		}
	)
	if payload != null:
		if payload.dynamic_value_thresholds != PackedInt32Array([20, 40, 70, 110, 160]):
			errors.append("%s effect.dynamic_value_thresholds mismatch: expected %s got %s" % [label, var_to_str(PackedInt32Array([20, 40, 70, 110, 160])), var_to_str(payload.dynamic_value_thresholds)])
		if payload.dynamic_value_outputs != PackedFloat32Array([9.0, 8.0, 7.0, 6.0, 5.0]):
			errors.append("%s effect.dynamic_value_outputs mismatch: expected %s got %s" % [label, var_to_str(PackedFloat32Array([9.0, 8.0, 7.0, 6.0, 5.0])), var_to_str(payload.dynamic_value_outputs)])
