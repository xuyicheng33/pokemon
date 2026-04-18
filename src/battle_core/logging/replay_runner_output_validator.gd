extends RefCounted
class_name ReplayRunnerOutputValidator

const EventTypesScript := preload("res://src/shared/event_types.gd")

func validate_log_schema_v3(event_log: Array) -> bool:
	var battle_header_count: int = 0
	for log_event in event_log:
		if log_event == null:
			return false
		if int(log_event.log_schema_version) != 3:
			return false
		if String(log_event.chain_origin).is_empty():
			return false
		if String(log_event.chain_origin) != "action":
			if String(log_event.command_type).is_empty():
				return false
			if not String(log_event.command_type).begins_with("system:"):
				return false
			if String(log_event.command_source) != "system":
				return false
		if String(log_event.event_type).is_empty():
			return false
		if String(log_event.event_chain_id).is_empty():
			return false
		if int(log_event.event_step_id) <= 0:
			return false
		if String(log_event.event_type) == EventTypesScript.SYSTEM_BATTLE_HEADER:
			battle_header_count += 1
			if String(log_event.command_type) != EventTypesScript.SYSTEM_BATTLE_HEADER:
				return false
			if not _validate_header_snapshot(log_event.header_snapshot):
				return false
		if String(log_event.event_type).begins_with("effect:"):
			if log_event.trigger_name == null:
				return false
			if log_event.cause_event_id == null or String(log_event.cause_event_id).is_empty():
				return false
			if String(log_event.cause_event_id) == "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]:
				return false
	return battle_header_count == 1

func validate_battle_result(battle_result) -> bool:
	if battle_result == null:
		return false
	if not battle_result.finished:
		return false
	if String(battle_result.result_type).is_empty():
		return false
	if String(battle_result.reason).is_empty():
		return false
	if battle_result.result_type == "win":
		return battle_result.winner_side_id != null
	if battle_result.result_type == "draw" or battle_result.result_type == "no_winner":
		return battle_result.winner_side_id == null
	return false

func validate_turn_timeline(turn_timeline: Array, event_log: Array) -> bool:
	if turn_timeline.is_empty():
		return false
	var expected_from: int = 0
	for frame_index in range(turn_timeline.size()):
		var raw_frame = turn_timeline[frame_index]
		if not (raw_frame is Dictionary):
			return false
		var frame: Dictionary = raw_frame
		if not (frame.get("public_snapshot", null) is Dictionary):
			return false
		var event_from := int(frame.get("event_from", -1))
		var event_to := int(frame.get("event_to", -1))
		if event_from < 0 or event_to < event_from or event_to > event_log.size():
			return false
		if frame_index == 0:
			if int(frame.get("turn_index", -1)) != 0:
				return false
			if event_from != 0 or event_to != 0:
				return false
		elif int(frame.get("turn_index", 0)) <= 0:
			return false
		if event_from != expected_from:
			return false
		expected_from = event_to
		if typeof(frame.get("battle_finished", null)) != TYPE_BOOL:
			return false
	return expected_from == event_log.size()

func _validate_header_snapshot(header_snapshot) -> bool:
	if typeof(header_snapshot) != TYPE_DICTIONARY:
		return false
	var required_fields: Array[String] = [
		"visibility_mode",
		"prebattle_public_teams",
		"initial_active_public_ids_by_side",
		"initial_field",
	]
	for field_name in required_fields:
		if not header_snapshot.has(field_name):
			return false
	return not _contains_private_instance_id_key(header_snapshot)

func _contains_private_instance_id_key(value) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value.keys():
			var key_text := String(key)
			if key_text == "unit_instance_id" or key_text.ends_with("_instance_id"):
				return true
			if _contains_private_instance_id_key(value[key]):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for element in value:
			if _contains_private_instance_id_key(element):
				return true
	return false
