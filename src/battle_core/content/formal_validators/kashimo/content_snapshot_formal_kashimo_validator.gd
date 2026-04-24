extends "res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalKashimoValidator

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const UltimateValidatorScript := preload("res://src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_ultimate_validator.gd")

var _helper = ContractHelperScript.new()
var _ultimate_validator = UltimateValidatorScript.new()

func validate(content_index: BattleContentIndex, errors: Array) -> void:
	_validate_unit_passive(content_index, errors)
	_validate_skill_effect(content_index, errors)
	_validate_ultimate_domain(content_index, errors)

func _validate_unit_passive(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_unit_contract_descriptor(
		self,
		content_index,
		errors,
		FormalCharacterBaselinesScript.unit_contract("kashimo_hajime")
	)
	_validate_charge_separation_contract(content_index, errors)
	_validate_charge_separation_effects(content_index, errors)

func _validate_charge_separation_contract(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_passive_skill_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.passive_contract("kashimo_hajime", "kashimo_charge_separation")]
	)

func _validate_charge_separation_effects(content_index: BattleContentIndex, errors: Array) -> void:
	_validate_apply_water_leak_listeners(content_index, errors)
	_validate_thunder_resist(content_index, errors)
	_validate_water_leak_self(content_index, errors)
	_validate_water_leak_counter(content_index, errors)

func _validate_thunder_resist(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[kashimo_hajime].thunder_resist"
	var effect_definition = _require_effect(content_index, errors, label, "kashimo_thunder_resist")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_thunder_resist", label)]
	)
	var payload = _extract_single_payload(errors, label, "kashimo_thunder_resist", effect_definition, RuleModPayloadScript, "rule_mod")
	if payload == null:
		return
	_expect_string(errors, "%s mod_kind" % label, payload.mod_kind, "incoming_action_final_mod")
	_expect_string(errors, "%s mod_op" % label, payload.mod_op, "mul")
	if float(payload.value) != 0.5:
		errors.append("%s value mismatch: expected 0.5 got %s" % [label, var_to_str(payload.value)])
	_expect_packed_string_array(errors, "%s required_incoming_command_types" % label, payload.required_incoming_command_types, PackedStringArray(["skill", "ultimate"]))
	_expect_packed_string_array(errors, "%s required_incoming_combat_type_ids" % label, payload.required_incoming_combat_type_ids, PackedStringArray(["thunder"]))

func _validate_apply_water_leak_listeners(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[kashimo_hajime].water_leak_listeners"
	var effect_definition = _require_effect(content_index, errors, label, "kashimo_apply_water_leak_listeners")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		self,
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
		_expect_payload_shape(errors, "%s payload[%d]" % [label, payload_index], payload, {"effect_definition_id": expected_effect_ids[payload_index]})

func _validate_water_leak_self(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[kashimo_hajime].water_leak_self"
	var effect_definition = _require_effect(content_index, errors, label, "kashimo_water_leak_self_listener")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_water_leak_self_listener", label)]
	)
	var payload = _extract_single_payload(errors, label, "kashimo_water_leak_self_listener", effect_definition, ResourceModPayloadScript, "resource_mod")
	_expect_payload_shape(errors, "%s effect" % label, payload, {"resource_key": "mp", "amount": -15})

func _validate_water_leak_counter(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[kashimo_hajime].water_leak_counter"
	var effect_definition = _require_effect(content_index, errors, label, "kashimo_water_leak_counter_listener")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_water_leak_counter_listener", label)]
	)
	var payload = _extract_single_payload(errors, label, "kashimo_water_leak_counter_listener", effect_definition, DamagePayloadScript, "damage")
	if payload == null:
		return
	_expect_int(errors, "%s amount" % label, payload.amount, 15)
	_expect_bool(errors, "%s use_formula" % label, payload.use_formula, false)
	_expect_string(errors, "%s combat_type_id" % label, payload.combat_type_id, "poison")

func _validate_skill_effect(content_index: BattleContentIndex, errors: Array) -> void:
	var regular_skill_ids := PackedStringArray([
		"kashimo_raiken",
		"kashimo_charge",
		"kashimo_feedback_strike",
		"kashimo_kyokyo_katsura",
	])
	_helper.validate_skill_contracts(
		self,
		content_index,
		errors,
		FormalCharacterBaselinesScript.skill_contracts("kashimo_hajime", regular_skill_ids)
	)
	_validate_kyokyo_contract(content_index, errors)
	_validate_charge_apply_consume(content_index, errors)

func _validate_kyokyo_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[kashimo_hajime].kyokyo"
	var effect_definition = _require_effect(content_index, errors, label, "kashimo_kyokyo_nullify")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_kyokyo_nullify", label)]
	)
	var payload = _extract_single_payload(errors, label, "kashimo_kyokyo_nullify", effect_definition, RuleModPayloadScript, "rule_mod")
	_expect_payload_shape(
		errors,
		"%s effect" % label,
		payload,
		{
			"mod_kind": "nullify_field_accuracy",
			"mod_op": "set",
			"value": true,
			"scope": "self",
			"duration_mode": "turns",
			"duration": 3,
			"decrement_on": "turn_end",
			"stacking": "refresh",
			"priority": 10,
		}
	)

func _validate_charge_apply_consume(content_index: BattleContentIndex, errors: Array) -> void:
	_validate_apply_charge(
		content_index,
		errors,
		"formal[kashimo_hajime].apply_negative_charge",
		"kashimo_apply_negative_charge",
		"target",
		"on_hit",
		"kashimo_negative_charge_mark"
	)
	_validate_apply_charge(
		content_index,
		errors,
		"formal[kashimo_hajime].apply_positive_charge",
		"kashimo_apply_positive_charge",
		"self",
		"on_cast",
		"kashimo_positive_charge_mark"
	)
	_validate_negative_charge_mark(content_index, errors)
	_validate_positive_charge_mark(content_index, errors)
	_validate_consume_charge(
		content_index,
		errors,
		"formal[kashimo_hajime].consume_positive_charge",
		"kashimo_consume_positive_charges",
		"self",
		"kashimo_positive_charge_mark"
	)
	_validate_consume_charge(
		content_index,
		errors,
		"formal[kashimo_hajime].consume_negative_charge",
		"kashimo_consume_negative_charges",
		"target",
		"kashimo_negative_charge_mark"
	)

func _validate_apply_charge(
	content_index: BattleContentIndex,
	errors: Array,
	label: String,
	effect_id: String,
	expected_scope: String,
	expected_trigger_name: String,
	expected_mark_effect_id: String
) -> void:
	var effect_definition = _require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(self, content_index, errors, [{
		"label": label,
		"effect_id": effect_id,
		"fields": {
			"scope": expected_scope,
			"trigger_names": PackedStringArray([expected_trigger_name]),
		},
	}])
	var payload = _extract_single_payload(errors, label, effect_id, effect_definition, ApplyEffectPayloadScript, "apply_effect")
	_expect_payload_shape(
		errors,
		"%s payload" % label,
		payload,
		{"effect_definition_id": expected_mark_effect_id}
	)

func _validate_negative_charge_mark(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[kashimo_hajime].negative_charge_mark"
	var effect_definition = _require_effect(content_index, errors, label, "kashimo_negative_charge_mark")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_negative_charge_mark", label)]
	)
	var damage_payload = _extract_single_payload(
		errors,
		label,
		"kashimo_negative_charge_mark",
		effect_definition,
		DamagePayloadScript,
		"damage"
	)
	_expect_payload_shape(
		errors,
		"%s payload" % label,
		damage_payload,
		{"amount": 8, "use_formula": false, "combat_type_id": "thunder"}
	)

func _validate_positive_charge_mark(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[kashimo_hajime].positive_charge_mark"
	var effect_definition = _require_effect(content_index, errors, label, "kashimo_positive_charge_mark")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_positive_charge_mark", label)]
	)
	var resource_payload = _extract_single_payload(
		errors,
		label,
		"kashimo_positive_charge_mark",
		effect_definition,
		ResourceModPayloadScript,
		"resource_mod"
	)
	_expect_payload_shape(
		errors,
		"%s payload" % label,
		resource_payload,
		{"resource_key": "mp", "amount": 5}
	)

func _validate_consume_charge(
	content_index: BattleContentIndex,
	errors: Array,
	label: String,
	effect_id: String,
	expected_scope: String,
	expected_mark_effect_id: String
) -> void:
	var effect_definition = _require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(self, content_index, errors, [{
		"label": label,
		"effect_id": effect_id,
		"fields": {
			"scope": expected_scope,
			"trigger_names": PackedStringArray(["on_hit"]),
		},
	}])
	var payload = _extract_single_payload(
		errors,
		label,
		effect_id,
		effect_definition,
		RemoveEffectPayloadScript,
		"remove_effect"
	)
	_expect_payload_shape(
		errors,
		"%s payload" % label,
		payload,
		{"effect_definition_id": expected_mark_effect_id, "remove_mode": "all"}
	)

func _validate_ultimate_domain(content_index: BattleContentIndex, errors: Array) -> void:
	_ultimate_validator.validate(content_index, errors)
