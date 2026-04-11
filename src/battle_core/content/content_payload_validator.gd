extends RefCounted
class_name ContentPayloadValidator

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")
const RuleModSchemaScript := preload("res://src/battle_core/content/rule_mod_schema.gd")

var _rule_mod_schema = RuleModSchemaScript.new()
var _allowed_stat_names := PackedStringArray([
	"attack",
	"defense",
	"sp_attack",
	"sp_defense",
	"speed",
])
var _allowed_stat_retention_modes := PackedStringArray(["normal", "persist_on_switch"])

static func validator_method_name_for_key(validator_key: String) -> String:
	var normalized_key := validator_key.strip_edges()
	if normalized_key.is_empty():
		return ""
	return "_validate_%s_payload" % normalized_key

func missing_registered_validator_keys() -> PackedStringArray:
	var missing_keys := PackedStringArray()
	for raw_validator_key in PayloadContractRegistryScript.registered_validator_keys():
		var validator_key := String(raw_validator_key).strip_edges()
		var method_name := validator_method_name_for_key(validator_key)
		if method_name.is_empty() or has_method(method_name):
			continue
		missing_keys.append(validator_key)
	return missing_keys

func validate_effect_refs(errors: Array, label: String, effect_ids: PackedStringArray, effects: Dictionary) -> void:
	for effect_id in effect_ids:
		if not effects.has(effect_id):
			errors.append("%s missing effect: %s" % [label, effect_id])

func validate_payload(errors: Array, effect_id: String, payload, content_index) -> void:
	if payload == null:
		errors.append("effect[%s].payloads contains null" % effect_id)
		return
	var validator_key := PayloadContractRegistryScript.validator_key_for_payload(payload)
	var validator_method_name := validator_method_name_for_key(validator_key)
	if validator_method_name.is_empty():
		errors.append("effect[%s].payloads invalid type: %s" % [effect_id, payload])
		return
	if not has_method(validator_method_name):
		errors.append("effect[%s].payloads missing validator dispatcher: %s" % [effect_id, validator_key])
		return
	call(validator_method_name, errors, effect_id, payload, content_index)

func _validate_damage_payload(errors: Array, effect_id: String, payload, content_index = null) -> void:
	if int(payload.amount) <= 0:
		errors.append("effect[%s].damage amount must be > 0, got %d" % [effect_id, int(payload.amount)])
	if bool(payload.use_formula):
		var formula_damage_kind := String(payload.damage_kind)
		if formula_damage_kind != ContentSchemaScript.DAMAGE_KIND_PHYSICAL and formula_damage_kind != ContentSchemaScript.DAMAGE_KIND_SPECIAL:
			errors.append("effect[%s].damage invalid damage_kind for formula: %s" % [effect_id, formula_damage_kind])
	elif not String(payload.combat_type_id).is_empty() and not content_index.combat_types.has(String(payload.combat_type_id)):
		errors.append("effect[%s].damage combat_type_id missing combat type: %s" % [effect_id, String(payload.combat_type_id)])

func _validate_heal_payload(errors: Array, effect_id: String, payload, _content_index = null) -> void:
	if bool(payload.use_percent):
		if int(payload.percent) < 1 or int(payload.percent) > 100:
			errors.append("effect[%s].heal percent out of range: %d" % [effect_id, int(payload.percent)])
		var percent_base := String(payload.percent_base)
		if percent_base != "max_hp" and percent_base != "missing_hp":
			errors.append("effect[%s].heal invalid percent_base: %s" % [effect_id, percent_base])
	elif int(payload.amount) <= 0:
		errors.append("effect[%s].heal amount must be > 0, got %d" % [effect_id, int(payload.amount)])

func _validate_resource_mod_payload(errors: Array, effect_id: String, payload, _content_index = null) -> void:
	if String(payload.resource_key) != "mp":
		errors.append("effect[%s].resource_mod invalid resource_key: %s" % [effect_id, payload.resource_key])

func _validate_stat_mod_payload(errors: Array, effect_id: String, payload, _content_index = null) -> void:
	if not _allowed_stat_names.has(String(payload.stat_name)):
		errors.append("effect[%s].stat_mod invalid stat_name: %s" % [effect_id, payload.stat_name])
	if not _allowed_stat_retention_modes.has(String(payload.retention_mode)):
		errors.append("effect[%s].stat_mod invalid retention_mode: %s" % [effect_id, String(payload.retention_mode)])

func _validate_apply_field_payload(errors: Array, effect_id: String, payload, content_index) -> void:
	if String(payload.field_definition_id).is_empty() or not content_index.fields.has(payload.field_definition_id):
		errors.append("effect[%s].apply_field missing field: %s" % [effect_id, payload.field_definition_id])
	validate_effect_refs(errors, "effect[%s].apply_field.on_success_effect_ids" % effect_id, payload.on_success_effect_ids, content_index.effects)

func _validate_apply_effect_payload(errors: Array, effect_id: String, payload, content_index) -> void:
	if String(payload.effect_definition_id).is_empty() or not content_index.effects.has(payload.effect_definition_id):
		errors.append("effect[%s].apply_effect missing effect: %s" % [effect_id, payload.effect_definition_id])

func _validate_remove_effect_payload(errors: Array, effect_id: String, payload, content_index) -> void:
	if String(payload.effect_definition_id).is_empty() or not content_index.effects.has(payload.effect_definition_id):
		errors.append("effect[%s].remove_effect missing effect: %s" % [effect_id, payload.effect_definition_id])
	if String(payload.remove_mode) != "single" and String(payload.remove_mode) != "all":
		errors.append("effect[%s].remove_effect invalid remove_mode: %s" % [effect_id, String(payload.remove_mode)])

func _validate_rule_mod_payload(errors: Array, effect_id: String, payload, content_index) -> void:
	var rule_mod_errors = _rule_mod_schema.validate_payload(payload, content_index)
	for error_msg in rule_mod_errors:
		errors.append("effect[%s].rule_mod invalid: %s" % [effect_id, error_msg])

func _validate_forced_replace_payload(errors: Array, effect_id: String, payload, _content_index = null) -> void:
	if payload.scope != "self" and payload.scope != "target":
		errors.append("effect[%s].forced_replace invalid scope: %s" % [effect_id, payload.scope])
	if String(payload.selector_reason).strip_edges().is_empty():
		errors.append("effect[%s].forced_replace selector_reason must not be empty" % effect_id)
