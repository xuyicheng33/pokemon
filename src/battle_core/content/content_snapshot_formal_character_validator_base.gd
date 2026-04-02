extends RefCounted
class_name ContentSnapshotFormalCharacterValidatorBase

func _extract_single_payload(
	errors: Array,
	label: String,
	effect_id: String,
	effect_definition,
	payload_script,
	payload_name: String
):
	var matched_payloads: Array = []
	for payload in effect_definition.payloads:
		if payload != null and payload.get_script() == payload_script:
			matched_payloads.append(payload)
	if matched_payloads.size() != 1:
		errors.append("%s effect[%s] must define exactly one %s payload, got %d" % [
			label,
			effect_id,
			payload_name,
			matched_payloads.size(),
		])
		return null
	return matched_payloads[0]

func _expect_packed_string_array(errors: Array, label: String, actual: PackedStringArray, expected: PackedStringArray) -> void:
	if actual == expected:
		return
	errors.append("%s mismatch: expected %s got %s" % [label, var_to_str(expected), var_to_str(actual)])
