extends RefCounted
class_name FormalCharacterManagerSmokeCommandHelper

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func build_command_result(
	helper,
	manager,
	turn_index: int,
	side_id: String,
	actor_public_id: String,
	action_spec,
	label: String = "build_command"
) -> Dictionary:
	var command_payload := {
		"turn_index": turn_index,
		"command_source": "manual",
		"side_id": side_id,
		"actor_public_id": actor_public_id,
	}
	var resolved_action = _resolve_action_payload(action_spec)
	if not bool(resolved_action.get("ok", false)):
		return resolved_action
	for key in resolved_action.get("data", {}).keys():
		command_payload[key] = resolved_action["data"][key]
	return helper.unwrap_ok(manager.build_command(command_payload), label)

func run_turn_result(helper, manager, session_id: String, turn_spec: Dictionary) -> Dictionary:
	var turn_index := int(turn_spec.get("turn_index", 0))
	if turn_index <= 0:
		return {"ok": false, "error": "run_turn turn_spec missing positive turn_index"}
	var p1_command = build_command_result(
		helper,
		manager,
		turn_index,
		"P1",
		String(turn_spec.get("p1_actor_public_id", "P1-A")),
		turn_spec.get("p1_action", "wait"),
		String(turn_spec.get("p1_label", "build_command(P1)"))
	)
	if not bool(p1_command.get("ok", false)):
		return p1_command
	var p2_command = build_command_result(
		helper,
		manager,
		turn_index,
		"P2",
		String(turn_spec.get("p2_actor_public_id", "P2-A")),
		turn_spec.get("p2_action", "wait"),
		String(turn_spec.get("p2_label", "build_command(P2)"))
	)
	if not bool(p2_command.get("ok", false)):
		return p2_command
	return helper.unwrap_ok(manager.run_turn(session_id, [
		p1_command.get("data", null),
		p2_command.get("data", null),
	]), String(turn_spec.get("label", "run_turn")))

func run_turn_sequence_result(helper, manager, session_id: String, turn_specs: Array) -> Dictionary:
	for raw_turn_spec in turn_specs:
		if not (raw_turn_spec is Dictionary):
			return {"ok": false, "error": "run_turn sequence item must be Dictionary"}
		var turn_result = run_turn_result(helper, manager, session_id, raw_turn_spec)
		if not bool(turn_result.get("ok", false)):
			return turn_result
	return {"ok": true}

func _resolve_action_payload(action_spec) -> Dictionary:
	if typeof(action_spec) == TYPE_STRING:
		var action_text := String(action_spec).strip_edges()
		if action_text.is_empty():
			return {"ok": false, "error": "build_command action_spec cannot be empty"}
		if action_text == "wait":
			return {"ok": true, "data": {"command_type": CommandTypesScript.WAIT}}
		if action_text.begins_with("switch:"):
			return {
				"ok": true,
				"data": {
					"command_type": CommandTypesScript.SWITCH,
					"target_public_id": String(action_text.split(":", false, 1)[1]).strip_edges(),
				},
			}
		return {
			"ok": true,
			"data": {
				"command_type": CommandTypesScript.SKILL,
				"skill_id": action_text,
			},
		}
	if not (action_spec is Dictionary):
		return {"ok": false, "error": "build_command action_spec must be String or Dictionary"}
	var payload: Dictionary = action_spec.duplicate(true)
	if payload.has("command_type"):
		return {"ok": true, "data": payload}
	match String(payload.get("action_kind", "skill")).strip_edges():
		"wait":
			payload["command_type"] = CommandTypesScript.WAIT
		"switch":
			payload["command_type"] = CommandTypesScript.SWITCH
		"ultimate":
			payload["command_type"] = CommandTypesScript.ULTIMATE
		_:
			payload["command_type"] = CommandTypesScript.SKILL
	return {"ok": true, "data": payload}
