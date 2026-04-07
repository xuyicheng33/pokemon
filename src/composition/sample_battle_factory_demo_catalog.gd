extends RefCounted
class_name SampleBattleFactoryDemoCatalog

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const DEFAULT_CATALOG_PATH := "res://config/demo_replay_catalog.json"

var catalog_path_override: String = ""

func default_profile_id() -> String:
	var catalog_result := default_profile_id_result()
	if not bool(catalog_result.get("ok", false)):
		return ""
	return String(catalog_result.get("data", "")).strip_edges()

func default_profile_id_result() -> Dictionary:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	return _ok_result(String(catalog_result.get("data", {}).get("default_profile_id", "")).strip_edges())

func profile_result(profile_id: String) -> Dictionary:
	var catalog_result := _load_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result
	var profiles: Dictionary = catalog_result.get("data", {}).get("profiles", {})
	var profile: Dictionary = profiles.get(profile_id, {})
	if profile.is_empty():
		return _error_result(
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			"SampleBattleFactory unknown demo replay profile: %s" % profile_id
		)
	return _ok_result(profile.duplicate(true))

func _load_catalog_result() -> Dictionary:
	var resolved_catalog_path := _resolve_catalog_path()
	var file := FileAccess.open(resolved_catalog_path, FileAccess.READ)
	if file == null:
		return _error_result(
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			"SampleBattleFactory missing demo replay catalog: %s" % resolved_catalog_path
		)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			"SampleBattleFactory expects top-level dictionary demo replay catalog: %s" % resolved_catalog_path
		)
	var profiles = parsed.get("profiles", {})
	if not (profiles is Dictionary) or profiles.is_empty():
		return _error_result(
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			"SampleBattleFactory demo replay catalog missing dictionary profiles: %s" % resolved_catalog_path
		)
	var default_profile_id := String(parsed.get("default_profile_id", "")).strip_edges()
	if default_profile_id.is_empty() or not profiles.has(default_profile_id):
		return _error_result(
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			"SampleBattleFactory demo replay catalog missing valid default_profile_id: %s" % resolved_catalog_path
		)
	for profile_id in profiles.keys():
		var profile = profiles.get(profile_id, {})
		if not (profile is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_REPLAY_INPUT,
				"SampleBattleFactory demo replay catalog[%s] must be dictionary: %s" % [String(profile_id), resolved_catalog_path]
			)
		var matchup_id := String(profile.get("matchup_id", "")).strip_edges()
		if matchup_id.is_empty():
			return _error_result(
				ErrorCodesScript.INVALID_REPLAY_INPUT,
				"SampleBattleFactory demo replay catalog[%s] missing matchup_id: %s" % [String(profile_id), resolved_catalog_path]
			)
		var battle_seed_result := _parse_positive_int_result(
			profile.get("battle_seed", null),
			"SampleBattleFactory demo replay catalog[%s] missing positive integer battle_seed: %s" % [String(profile_id), resolved_catalog_path]
		)
		if not bool(battle_seed_result.get("ok", false)):
			return _error_result(
				ErrorCodesScript.INVALID_REPLAY_INPUT,
				String(battle_seed_result.get("error_message", "SampleBattleFactory demo replay catalog battle_seed validation failed"))
			)
		profile["battle_seed"] = int(battle_seed_result.get("data", 0))
		var commands = profile.get("commands", null)
		if not (commands is Array) or commands.is_empty():
			return _error_result(
				ErrorCodesScript.INVALID_REPLAY_INPUT,
				"SampleBattleFactory demo replay catalog[%s] missing non-empty commands: %s" % [String(profile_id), resolved_catalog_path]
			)
		for command_index in range(commands.size()):
			var command_payload = commands[command_index]
			if not (command_payload is Dictionary):
				return _error_result(
					ErrorCodesScript.INVALID_REPLAY_INPUT,
					"SampleBattleFactory demo replay catalog[%s].commands[%d] must be dictionary: %s" % [String(profile_id), command_index, resolved_catalog_path]
				)
			var validation_message := _validate_command_payload(String(profile_id), resolved_catalog_path, command_payload, command_index)
			if not validation_message.is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_REPLAY_INPUT,
					validation_message
				)
	return _ok_result(parsed)

func _validate_command_payload(profile_id: String, catalog_path: String, command_payload: Dictionary, command_index: int) -> String:
	for required_key in ["turn_index", "command_type", "command_source", "side_id", "actor_public_id"]:
		var value = command_payload.get(required_key, null)
		if required_key == "turn_index":
			var turn_index_result := _parse_positive_int_result(
				value,
				"SampleBattleFactory demo replay catalog[%s].commands[%d] missing positive integer %s: %s" % [
					profile_id,
					command_index,
					required_key,
					catalog_path,
				]
			)
			if bool(turn_index_result.get("ok", false)):
				command_payload["turn_index"] = int(turn_index_result.get("data", 0))
				continue
			return String(turn_index_result.get("error_message", "SampleBattleFactory demo replay command turn_index validation failed"))
		if String(value).strip_edges().is_empty():
			return "SampleBattleFactory demo replay catalog[%s].commands[%d] missing %s: %s" % [
				profile_id,
				command_index,
				required_key,
				catalog_path,
			]
	var command_type := String(command_payload.get("command_type", "")).strip_edges()
	if command_type == "wait":
		return ""
	if command_type == "switch":
		if String(command_payload.get("target_public_id", "")).strip_edges().is_empty():
			return "SampleBattleFactory demo replay catalog[%s].commands[%d] missing target_public_id: %s" % [
				profile_id,
				command_index,
				catalog_path,
			]
		return ""
	if command_type != "skill" and command_type != "ultimate":
		return "SampleBattleFactory demo replay catalog[%s].commands[%d] unsupported command_type=%s: %s" % [
			profile_id,
			command_index,
			command_type,
			catalog_path,
		]
	if String(command_payload.get("skill_id", "")).strip_edges().is_empty():
		return "SampleBattleFactory demo replay catalog[%s].commands[%d] missing skill_id: %s" % [
			profile_id,
			command_index,
			catalog_path,
		]
	return ""

func _resolve_catalog_path() -> String:
	var trimmed_path := String(catalog_path_override).strip_edges()
	if trimmed_path.is_empty():
		return DEFAULT_CATALOG_PATH
	return trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path

func _parse_positive_int_result(value, error_message: String) -> Dictionary:
	if typeof(value) == TYPE_INT:
		if int(value) > 0:
			return _ok_result(int(value))
		return _error_result(ErrorCodesScript.INVALID_REPLAY_INPUT, error_message)
	if typeof(value) == TYPE_FLOAT:
		var float_value := float(value)
		var int_value := int(float_value)
		if float_value == float(int_value) and int_value > 0:
			return _ok_result(int_value)
	return _error_result(ErrorCodesScript.INVALID_REPLAY_INPUT, error_message)

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
