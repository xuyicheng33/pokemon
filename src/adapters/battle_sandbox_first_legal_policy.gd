extends "res://src/adapters/battle_sandbox_policy_port.gd"
class_name BattleSandboxFirstLegalPolicy

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const PropertyAccessHelperScript := preload("res://src/shared/property_access_helper.gd")

func select_action_result(legal_actions, _public_snapshot: Dictionary = {}, _controller_context: Dictionary = {}) -> Dictionary:
	if legal_actions == null:
		return _fail("policy requires non-null legal actions")
	var forced_command_type := str(_read_property(legal_actions, "forced_command_type", "")).strip_edges()
	if not forced_command_type.is_empty():
		return {"ok": true, "data": {"command_type": forced_command_type}}
	var legal_ultimate_ids := _to_string_array(_read_property(legal_actions, "legal_ultimate_ids", []))
	if not legal_ultimate_ids.is_empty():
		return {
			"ok": true,
			"data": {
				"command_type": CommandTypesScript.ULTIMATE,
				"skill_id": str(legal_ultimate_ids[0]),
			},
		}
	var legal_skill_ids := _to_string_array(_read_property(legal_actions, "legal_skill_ids", []))
	if not legal_skill_ids.is_empty():
		return {
			"ok": true,
			"data": {
				"command_type": CommandTypesScript.SKILL,
				"skill_id": str(legal_skill_ids[0]),
			},
		}
	var legal_switch_target_public_ids := _to_string_array(_read_property(legal_actions, "legal_switch_target_public_ids", []))
	if not legal_switch_target_public_ids.is_empty():
		return {
			"ok": true,
			"data": {
				"command_type": CommandTypesScript.SWITCH,
				"target_public_id": str(legal_switch_target_public_ids[0]),
			},
		}
	if bool(_read_property(legal_actions, "wait_allowed", false)):
		return {"ok": true, "data": {"command_type": CommandTypesScript.WAIT}}
	return _fail("policy found no legal action to submit")

func _read_property(value, property_name: String, default_value = null):
	return PropertyAccessHelperScript.read_property(value, property_name, default_value)

func _to_string_array(raw_value) -> Array:
	var result: Array = []
	if raw_value == null:
		return result
	if raw_value is PackedStringArray:
		for raw_item in raw_value:
			result.append(str(raw_item).strip_edges())
		return result
	if raw_value is Array:
		for raw_item in raw_value:
			result.append(str(raw_item).strip_edges())
	return result

func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
