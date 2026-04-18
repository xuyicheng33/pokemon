extends RefCounted
class_name FieldChange

var change_kind: String = ""
var before_field_id: Variant = null
var after_field_id: Variant = null
var before_remaining_turns: Variant = null
var after_remaining_turns: Variant = null

func to_stable_dict() -> Dictionary:
	return {
		"change_kind": change_kind,
		"before_field_id": before_field_id,
		"after_field_id": after_field_id,
		"before_remaining_turns": before_remaining_turns,
		"after_remaining_turns": after_remaining_turns,
	}
