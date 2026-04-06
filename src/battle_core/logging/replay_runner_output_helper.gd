extends RefCounted
class_name ReplayRunnerOutputHelper

const ReplayOutputScript := preload("res://src/battle_core/contracts/replay_output.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func build_replay_output(event_log: Array, battle_state):
	var replay_output = ReplayOutputScript.new()
	replay_output.event_log = event_log
	replay_output.final_state_hash = _compute_state_hash(battle_state)
	var run_completed: bool = battle_state.battle_result != null and battle_state.battle_result.finished
	replay_output.succeeded = run_completed and _validate_log_schema_v3(replay_output.event_log) and _validate_battle_result(battle_state.battle_result)
	replay_output.battle_result = battle_state.battle_result
	replay_output.final_battle_state = battle_state
	return replay_output

func _compute_state_hash(battle_state) -> String:
	var json_text := JSON.stringify(battle_state.to_stable_dict())
	var hashing_context = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(json_text.to_utf8_buffer())
	return hashing_context.finish().hex_encode()

func _validate_log_schema_v3(event_log: Array) -> bool:
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

func _validate_battle_result(battle_result) -> bool:
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
