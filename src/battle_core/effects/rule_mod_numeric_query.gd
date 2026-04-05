extends RefCounted
class_name RuleModNumericQuery

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

func resolve_final_multiplier(ordered_instances: Array) -> float:
	return _resolve_multiplier(ordered_instances, ContentSchemaScript.RULE_MOD_FINAL_MOD, 1.0)

func resolve_mp_regen_value(ordered_instances: Array, base_regen: int) -> int:
	var regen_value: int = base_regen
	for rule_mod_instance in ordered_instances:
		if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_MP_REGEN:
			continue
		match rule_mod_instance.mod_op:
			"add":
				regen_value += int(rule_mod_instance.value)
			"set":
				regen_value = int(rule_mod_instance.value)
	return max(0, regen_value)

func resolve_incoming_accuracy(ordered_instances: Array, base_accuracy: int) -> int:
	var resolved_accuracy: int = base_accuracy
	for rule_mod_instance in ordered_instances:
		if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_INCOMING_ACCURACY:
			continue
		match rule_mod_instance.mod_op:
			"add":
				resolved_accuracy += int(rule_mod_instance.value)
			"set":
				resolved_accuracy = int(rule_mod_instance.value)
	return clamp(resolved_accuracy, 0, 99)

func has_nullify_field_accuracy(ordered_instances: Array) -> bool:
	var is_enabled := false
	for rule_mod_instance in ordered_instances:
		if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_NULLIFY_FIELD_ACCURACY:
			continue
		if rule_mod_instance.mod_op == "set":
			is_enabled = bool(rule_mod_instance.value)
	return is_enabled

func resolve_incoming_heal_final_multiplier(ordered_instances: Array) -> float:
	return _resolve_multiplier(ordered_instances, ContentSchemaScript.RULE_MOD_INCOMING_HEAL_FINAL_MOD, 1.0)

func resolve_incoming_action_final_multiplier(ordered_instances: Array, command_type: String, combat_type_id: String) -> float:
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
	return final_multiplier

func _resolve_multiplier(ordered_instances: Array, mod_kind: String, base_value: float) -> float:
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
	return final_multiplier

func _incoming_action_filters_match(rule_mod_instance, command_type: String, combat_type_id: String) -> bool:
	var command_filters: PackedStringArray = rule_mod_instance.required_incoming_command_types
	if not command_filters.is_empty() and not command_filters.has(command_type):
		return false
	var combat_type_filters: PackedStringArray = rule_mod_instance.required_incoming_combat_type_ids
	if not combat_type_filters.is_empty() and not combat_type_filters.has(combat_type_id):
		return false
	return true
