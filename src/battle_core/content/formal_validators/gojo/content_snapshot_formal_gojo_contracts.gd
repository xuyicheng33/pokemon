extends RefCounted
class_name ContentSnapshotFormalGojoContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate_unit_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_unit_contract_descriptor(
		validator,
		content_index,
		errors,
		FormalCharacterBaselinesScript.unit_contract("gojo_satoru")
	)

func validate_core_skill_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(
		validator,
		content_index,
		errors,
		FormalCharacterBaselinesScript.skill_contracts(
			"gojo_satoru",
			PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki", "gojo_reverse_ritual"])
		)
	)

func validate_marker_contract(validator, content_index, errors: Array) -> void:
	_validate_marker_effect(validator, content_index, errors, "formal[gojo_satoru].ao_mark", "gojo_ao_mark", "gojo_ao_speed_up", "speed", 1)
	_validate_marker_effect(validator, content_index, errors, "formal[gojo_satoru].aka_mark", "gojo_aka_mark", "gojo_aka_slow_down", "speed", -1)

func _validate_marker_effect(
	validator,
	content_index,
	errors: Array,
	label: String,
	marker_effect_id: String,
	stat_effect_id: String,
	expected_stat_name: String,
	expected_stage_delta: int
) -> void:
	var marker_effect = validator._require_effect(content_index, errors, label, marker_effect_id)
	if marker_effect != null:
		_helper.validate_effect_contracts(
			validator,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("gojo_satoru", marker_effect_id, label)]
		)
	var apply_effect_id := "%s_apply" % marker_effect_id
	var apply_effect = validator._require_effect(content_index, errors, label, apply_effect_id)
	if apply_effect != null:
		var apply_payload = validator._extract_single_payload(errors, label, apply_effect_id, apply_effect, ApplyEffectPayloadScript, "apply_effect")
		validator._expect_payload_shape(errors, "%s effect[%s]" % [label, apply_effect_id], apply_payload, {"effect_definition_id": marker_effect_id})
	var stat_effect = validator._require_effect(content_index, errors, label, stat_effect_id)
	if stat_effect == null:
		return
	var stat_payload = validator._extract_single_payload(errors, label, stat_effect_id, stat_effect, StatModPayloadScript, "stat_mod")
	if stat_payload == null:
		return
	validator._expect_payload_shape(
		errors,
		"%s effect[%s]" % [label, stat_effect_id],
		stat_payload,
		{
			"stat_name": expected_stat_name,
			"stage_delta": expected_stage_delta,
		}
	)
