extends "res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalKashimoUltimateDomainContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.skill_contract("kashimo", "kashimo_phantom_beast_amber")]
	)
	_validate_amber_contract(validator, content_index, errors)

func _validate_amber_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].amber_contract"
	var amber_effect = validator._require_effect(content_index, errors, label, "kashimo_amber_self_transform")
	var amber_bleed = validator._require_effect(content_index, errors, label, "kashimo_amber_bleed")
	if amber_effect == null or amber_bleed == null:
		return
	validator._expect_string(errors, "%s effect.scope" % label, amber_effect.scope, "self")
	validator._expect_packed_string_array(errors, "%s effect.trigger_names" % label, amber_effect.trigger_names, PackedStringArray(["on_cast"]))
	var stat_payloads := _extract_stat_payloads(amber_effect)
	_expect_persistent_stat_mod(validator, errors, label, stat_payloads, "attack", 2)
	_expect_persistent_stat_mod(validator, errors, label, stat_payloads, "sp_attack", 2)
	_expect_persistent_stat_mod(validator, errors, label, stat_payloads, "speed", 1)
	var bleed_apply = validator._extract_single_payload(
		errors,
		label,
		"kashimo_amber_self_transform",
		amber_effect,
		ApplyEffectPayloadScript,
		"apply_effect"
	)
	if bleed_apply != null and String(bleed_apply.effect_definition_id) != "kashimo_amber_bleed":
		errors.append("%s amber bleed apply mismatch: expected kashimo_amber_bleed got %s" % [
			label,
			String(bleed_apply.effect_definition_id),
		])
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
	_helper.validate_effect_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo", "kashimo_amber_bleed", "%s bleed" % label)]
	)
	var bleed_payload = validator._extract_single_payload(
		errors,
		label,
		"kashimo_amber_bleed",
		amber_bleed,
		DamagePayloadScript,
		"damage"
	)
	validator._expect_payload_shape(
		errors,
		"%s bleed" % label,
		bleed_payload,
		{"amount": 20, "use_formula": false, "combat_type_id": ""}
	)

func _extract_stat_payloads(effect_definition) -> Array:
	var matched_payloads: Array = []
	for payload in effect_definition.payloads:
		if payload is StatModPayloadScript:
			matched_payloads.append(payload)
	return matched_payloads

func _extract_rule_mod_by_kind(effect_definition, mod_kind: String) -> Variant:
	for payload in effect_definition.payloads:
		if payload is RuleModPayloadScript and String(payload.mod_kind) == mod_kind:
			return payload
	return null

func _expect_persistent_stat_mod(validator, errors: Array, label: String, stat_payloads: Array, stat_name: String, stage_delta: int) -> void:
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
