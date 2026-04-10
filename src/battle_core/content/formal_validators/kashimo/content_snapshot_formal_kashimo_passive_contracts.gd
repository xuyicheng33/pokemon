extends RefCounted
class_name ContentSnapshotFormalKashimoPassiveContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate_charge_separation_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_passive_skill_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.passive_contract("kashimo_hajime", "kashimo_charge_separation")]
	)

func validate_charge_separation_effects(validator, content_index, errors: Array) -> void:
	_validate_apply_water_leak_listeners(validator, content_index, errors)
	_validate_thunder_resist(validator, content_index, errors)
	_validate_water_leak_self(validator, content_index, errors)
	_validate_water_leak_counter(validator, content_index, errors)

func _validate_thunder_resist(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo_hajime].thunder_resist"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_thunder_resist")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_thunder_resist", label)]
	)
	var payload = validator._extract_single_payload(errors, label, "kashimo_thunder_resist", effect_definition, RuleModPayloadScript, "rule_mod")
	if payload == null:
		return
	validator._expect_string(errors, "%s mod_kind" % label, payload.mod_kind, "incoming_action_final_mod")
	validator._expect_string(errors, "%s mod_op" % label, payload.mod_op, "mul")
	if float(payload.value) != 0.5:
		errors.append("%s value mismatch: expected 0.5 got %s" % [label, var_to_str(payload.value)])
	validator._expect_packed_string_array(errors, "%s required_incoming_command_types" % label, payload.required_incoming_command_types, PackedStringArray(["skill", "ultimate"]))
	validator._expect_packed_string_array(errors, "%s required_incoming_combat_type_ids" % label, payload.required_incoming_combat_type_ids, PackedStringArray(["thunder"]))

func _validate_apply_water_leak_listeners(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo_hajime].water_leak_listeners"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_apply_water_leak_listeners")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_apply_water_leak_listeners", label)]
	)
	if effect_definition.payloads.size() != 2:
		errors.append("%s payload count mismatch: expected 2 got %d" % [label, effect_definition.payloads.size()])
		return
	var expected_effect_ids := PackedStringArray(["kashimo_water_leak_self_listener", "kashimo_water_leak_counter_listener"])
	for payload_index in range(expected_effect_ids.size()):
		var payload = effect_definition.payloads[payload_index]
		if payload == null or payload.get_script() != ApplyEffectPayloadScript:
			errors.append("%s payload[%d] must be apply_effect" % [label, payload_index])
			continue
		validator._expect_payload_shape(errors, "%s payload[%d]" % [label, payload_index], payload, {"effect_definition_id": expected_effect_ids[payload_index]})

func _validate_water_leak_self(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo_hajime].water_leak_self"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_water_leak_self_listener")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_water_leak_self_listener", label)]
	)
	var payload = validator._extract_single_payload(errors, label, "kashimo_water_leak_self_listener", effect_definition, ResourceModPayloadScript, "resource_mod")
	validator._expect_payload_shape(errors, "%s effect" % label, payload, {"resource_key": "mp", "amount": -15})

func _validate_water_leak_counter(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo_hajime].water_leak_counter"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_water_leak_counter_listener")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_water_leak_counter_listener", label)]
	)
	var payload = validator._extract_single_payload(errors, label, "kashimo_water_leak_counter_listener", effect_definition, DamagePayloadScript, "damage")
	if payload == null:
		return
	validator._expect_int(errors, "%s amount" % label, payload.amount, 15)
	validator._expect_bool(errors, "%s use_formula" % label, payload.use_formula, false)
	validator._expect_string(errors, "%s combat_type_id" % label, payload.combat_type_id, "poison")
