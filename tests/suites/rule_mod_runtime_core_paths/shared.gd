extends RefCounted

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

func build_numeric_rule_mod_payload(mod_kind: String, mod_op: String, value, source_group: String):
	var payload = RuleModPayloadScript.new()
	payload.payload_type = "rule_mod"
	payload.mod_kind = mod_kind
	payload.mod_op = mod_op
	payload.value = value
	payload.scope = "self"
	payload.duration_mode = "turns"
	payload.duration = 2
	payload.decrement_on = "turn_start"
	payload.stacking = "replace"
	payload.priority = 5
	payload.stacking_source_key = source_group
	return payload

func count_rule_mod_instances(unit_state, mod_kind: String) -> int:
	var count := 0
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) == mod_kind:
			count += 1
	return count

func unit_rule_mods_have_source_keys(unit_state, mod_kind: String, expected_keys: PackedStringArray) -> bool:
	var actual_keys: Array[String] = []
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) != mod_kind:
			continue
		actual_keys.append(String(rule_mod_instance.source_stacking_key))
	actual_keys.sort()
	var sorted_expected: Array[String] = []
	for expected_key in expected_keys:
		sorted_expected.append(String(expected_key))
	sorted_expected.sort()
	return actual_keys == sorted_expected
