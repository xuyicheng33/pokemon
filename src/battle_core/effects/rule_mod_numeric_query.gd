extends RefCounted
class_name RuleModNumericQuery

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func resolve_final_multiplier(ordered_instances: Array) -> float:
	return _float_value(resolve_final_multiplier_result(ordered_instances), 1.0)

func resolve_final_multiplier_result(ordered_instances: Array) -> Dictionary:
	return _resolve_multiplier_result(ordered_instances, ContentSchemaScript.RULE_MOD_FINAL_MOD, 1.0)

func resolve_mp_regen_value(ordered_instances: Array, base_regen: int) -> int:
	return _int_value(resolve_mp_regen_value_result(ordered_instances, base_regen), max(0, base_regen))

func resolve_mp_regen_value_result(ordered_instances: Array, base_regen: int) -> Dictionary:
	var regen_value: int = base_regen
	for rule_mod_instance in ordered_instances:
		if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_MP_REGEN:
			continue
		match rule_mod_instance.mod_op:
			"add":
				regen_value += int(rule_mod_instance.value)
			"set":
				regen_value = int(rule_mod_instance.value)
			_:
				return _error("unsupported mp_regen mod_op: %s" % String(rule_mod_instance.mod_op))
	return _value(max(0, regen_value))

func resolve_incoming_accuracy(ordered_instances: Array, base_accuracy: int) -> int:
	return _int_value(resolve_incoming_accuracy_result(ordered_instances, base_accuracy), clamp(base_accuracy, 0, 99))

func resolve_incoming_accuracy_result(ordered_instances: Array, base_accuracy: int) -> Dictionary:
	var resolved_accuracy: int = base_accuracy
	for rule_mod_instance in ordered_instances:
		if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_INCOMING_ACCURACY:
			continue
		match rule_mod_instance.mod_op:
			"add":
				resolved_accuracy += int(rule_mod_instance.value)
			"set":
				resolved_accuracy = int(rule_mod_instance.value)
			_:
				return _error("unsupported incoming_accuracy mod_op: %s" % String(rule_mod_instance.mod_op))
	return _value(clamp(resolved_accuracy, 0, 99))

func has_nullify_field_accuracy(ordered_instances: Array) -> bool:
	return bool(has_nullify_field_accuracy_result(ordered_instances).get("value", false))

func has_nullify_field_accuracy_result(ordered_instances: Array) -> Dictionary:
	var is_enabled := false
	for rule_mod_instance in ordered_instances:
		if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_NULLIFY_FIELD_ACCURACY:
			continue
		if rule_mod_instance.mod_op != "set":
			return _error("unsupported nullify_field_accuracy mod_op: %s" % String(rule_mod_instance.mod_op))
		is_enabled = bool(rule_mod_instance.value)
	return _value(is_enabled)

func resolve_incoming_heal_final_multiplier(ordered_instances: Array) -> float:
	return _float_value(resolve_incoming_heal_final_multiplier_result(ordered_instances), 1.0)

func resolve_incoming_heal_final_multiplier_result(ordered_instances: Array) -> Dictionary:
	return _resolve_multiplier_result(ordered_instances, ContentSchemaScript.RULE_MOD_INCOMING_HEAL_FINAL_MOD, 1.0)

func resolve_incoming_action_final_multiplier(ordered_instances: Array, command_type: String, combat_type_id: String) -> float:
	return _float_value(resolve_incoming_action_final_multiplier_result(ordered_instances, command_type, combat_type_id), 1.0)

func resolve_incoming_action_final_multiplier_result(ordered_instances: Array, command_type: String, combat_type_id: String) -> Dictionary:
	var final_multiplier: float = 1.0
	for rule_mod_instance in ordered_instances:
		if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_INCOMING_ACTION_FINAL_MOD:
			continue
		if not _incoming_action_filters_match(rule_mod_instance, command_type, combat_type_id):
			continue
		match rule_mod_instance.mod_op:
			"mul":
				final_multiplier *= float(rule_mod_instance.value)
			"add":
				final_multiplier += float(rule_mod_instance.value)
			"set":
				final_multiplier = float(rule_mod_instance.value)
			_:
				return _error("unsupported incoming_action_final_mod mod_op: %s" % String(rule_mod_instance.mod_op))
	return _value(final_multiplier)

func _resolve_multiplier(ordered_instances: Array, mod_kind: String, base_value: float) -> float:
	return _float_value(_resolve_multiplier_result(ordered_instances, mod_kind, base_value), base_value)

func _resolve_multiplier_result(ordered_instances: Array, mod_kind: String, base_value: float) -> Dictionary:
	var final_multiplier: float = base_value
	for rule_mod_instance in ordered_instances:
		if rule_mod_instance.mod_kind != mod_kind:
			continue
		match rule_mod_instance.mod_op:
			"mul":
				final_multiplier *= float(rule_mod_instance.value)
			"add":
				final_multiplier += float(rule_mod_instance.value)
			"set":
				final_multiplier = float(rule_mod_instance.value)
			_:
				return _error("unsupported %s mod_op: %s" % [mod_kind, String(rule_mod_instance.mod_op)])
	return _value(final_multiplier)

func _incoming_action_filters_match(rule_mod_instance, command_type: String, combat_type_id: String) -> bool:
	var command_filters: PackedStringArray = rule_mod_instance.required_incoming_command_types
	if not command_filters.is_empty() and not command_filters.has(command_type):
		return false
	var combat_type_filters: PackedStringArray = rule_mod_instance.required_incoming_combat_type_ids
	if not combat_type_filters.is_empty() and not combat_type_filters.has(combat_type_id):
		return false
	return true

func _value(value) -> Dictionary:
	return {"value": value, "error_code": null, "error_message": ""}

func _error(message: String) -> Dictionary:
	return {"value": null, "error_code": ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "error_message": message}

func _int_value(result: Dictionary, fallback: int) -> int:
	var value = result.get("value", fallback)
	return fallback if value == null else int(value)

func _float_value(result: Dictionary, fallback: float) -> float:
	var value = result.get("value", fallback)
	return fallback if value == null else float(value)
