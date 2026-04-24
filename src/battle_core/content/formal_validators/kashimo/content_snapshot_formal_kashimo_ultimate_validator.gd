extends "res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalKashimoUltimateValidator

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_skill_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.skill_contract("kashimo_hajime", "kashimo_phantom_beast_amber")]
	)
	_validate_amber_contract(content_index, errors)

func _validate_amber_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[kashimo_hajime].amber_contract"
	var amber_effect = _require_effect(content_index, errors, label, "kashimo_amber_self_transform")
	var amber_bleed = _require_effect(content_index, errors, label, "kashimo_amber_bleed")
	if amber_effect == null or amber_bleed == null:
		return
	_expect_string(errors, "%s effect.scope" % label, amber_effect.scope, "self")
	_expect_packed_string_array(errors, "%s effect.trigger_names" % label, amber_effect.trigger_names, PackedStringArray(["on_cast"]))
	var stat_payloads := _helper.extract_payloads_by_script(amber_effect, StatModPayloadScript)
	_helper.expect_payload_shape_by_field(
		self,
		errors,
		"%s stat[attack]" % label,
		stat_payloads,
		"stat_name",
		"attack",
		StatModPayloadScript,
		"stat_mod",
		{"stat_name": "attack", "stage_delta": 2, "retention_mode": "persist_on_switch"}
	)
	_helper.expect_payload_shape_by_field(
		self,
		errors,
		"%s stat[sp_attack]" % label,
		stat_payloads,
		"stat_name",
		"sp_attack",
		StatModPayloadScript,
		"stat_mod",
		{"stat_name": "sp_attack", "stage_delta": 2, "retention_mode": "persist_on_switch"}
	)
	_helper.expect_payload_shape_by_field(
		self,
		errors,
		"%s stat[speed]" % label,
		stat_payloads,
		"stat_name",
		"speed",
		StatModPayloadScript,
		"stat_mod",
		{"stat_name": "speed", "stage_delta": 1, "retention_mode": "persist_on_switch"}
	)
	var bleed_apply = _extract_single_payload(
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
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo_hajime", "kashimo_amber_bleed", "%s bleed" % label)]
	)
	var bleed_payload = _extract_single_payload(
		errors,
		label,
		"kashimo_amber_bleed",
		amber_bleed,
		DamagePayloadScript,
		"damage"
	)
	_expect_payload_shape(
		errors,
		"%s bleed" % label,
		bleed_payload,
		{"amount": 20, "use_formula": false, "combat_type_id": ""}
	)

func _extract_rule_mod_by_kind(effect_definition, mod_kind: String) -> Variant:
	for payload in effect_definition.payloads:
		if payload is RuleModPayloadScript and String(payload.mod_kind) == mod_kind:
			return payload
	return null
