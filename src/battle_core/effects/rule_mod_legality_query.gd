extends RefCounted
class_name RuleModLegalityQuery

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func is_action_allowed(ordered_instances: Array, action_type: String, skill_id: String = "") -> Dictionary:
	if _is_always_allowed_action_type(action_type):
		return {"allowed": true, "error_code": null, "error_message": ""}
	if not _is_managed_action_type(action_type):
		return _build_unsupported_action_type_error(action_type)
	var allowed: bool = true
	for rule_mod_instance in ordered_instances:
		if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_ACTION_LEGALITY:
			continue
		var match_result := _action_legality_matches(rule_mod_instance, action_type, skill_id)
		if match_result.get("error_code", null) != null:
			return match_result
		if not bool(match_result.get("matches", false)):
			continue
		allowed = rule_mod_instance.mod_op == "allow"
	return {"allowed": allowed, "error_code": null, "error_message": ""}

func _action_legality_matches(rule_mod_instance, action_type: String, skill_id: String) -> Dictionary:
	var match_token_result := _build_action_legality_match_tokens(action_type, skill_id)
	if match_token_result.get("error_code", null) != null:
		return match_token_result
	var value := String(rule_mod_instance.value).strip_edges()
	var match_tokens: PackedStringArray = match_token_result.get("match_tokens", PackedStringArray())
	return {
		"matches": match_tokens.has(value),
		"allowed": false,
		"error_code": null,
		"error_message": "",
	}

func _build_action_legality_match_tokens(action_type: String, skill_id: String) -> Dictionary:
	if not _is_managed_action_type(action_type):
		return _build_unsupported_action_type_error(action_type)
	var match_tokens := PackedStringArray()
	match String(action_type):
		ContentSchemaScript.ACTION_LEGALITY_SKILL:
			match_tokens = PackedStringArray([
				ContentSchemaScript.ACTION_LEGALITY_ALL,
				ContentSchemaScript.ACTION_LEGALITY_SKILL,
			])
		ContentSchemaScript.ACTION_LEGALITY_ULTIMATE:
			match_tokens = PackedStringArray([
				ContentSchemaScript.ACTION_LEGALITY_ALL,
				ContentSchemaScript.ACTION_LEGALITY_ULTIMATE,
			])
		ContentSchemaScript.ACTION_LEGALITY_SWITCH:
			match_tokens = PackedStringArray([
				ContentSchemaScript.ACTION_LEGALITY_ALL,
				ContentSchemaScript.ACTION_LEGALITY_SWITCH,
			])
		_:
			return _build_unsupported_action_type_error(action_type)
	if String(action_type) != ContentSchemaScript.ACTION_LEGALITY_SWITCH and not skill_id.is_empty():
		match_tokens.append(skill_id)
	return {
		"match_tokens": match_tokens,
		"allowed": false,
		"error_code": null,
		"error_message": "",
	}

func _is_managed_action_type(action_type: String) -> bool:
	return ContentSchemaScript.managed_action_types().has(String(action_type))

func _is_always_allowed_action_type(action_type: String) -> bool:
	return ContentSchemaScript.always_allowed_action_types().has(String(action_type))

func _build_unsupported_action_type_error(action_type: String) -> Dictionary:
	return {
		"allowed": false,
		"error_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD,
		"error_message": "unsupported action_legality action_type: %s" % String(action_type),
	}
