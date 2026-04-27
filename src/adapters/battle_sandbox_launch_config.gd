extends RefCounted
class_name BattleSandboxLaunchConfig

const MODE_MANUAL_MATCHUP := "manual_matchup"
const MODE_DEMO_REPLAY := "demo_replay"
const CONTROL_MODE_MANUAL := "manual"
const CONTROL_MODE_POLICY := "policy"
const DEFAULT_MATCHUP_ID := "gojo_vs_sample"
const DEFAULT_BATTLE_SEED := 9101
const SAMPLE_DEFAULT_MATCHUP_ID := "sample_default"
const SIDE_IDS := ["P1", "P2"]
const ERROR_MESSAGE_KEY := "error_message"
const STRICT_CONFIG_KEY := "strict_config"
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")

var _manifest = FormalCharacterManifestScript.new()

func default_config() -> Dictionary:
	return {
		"mode": MODE_MANUAL_MATCHUP,
		"matchup_id": DEFAULT_MATCHUP_ID,
		"battle_seed": DEFAULT_BATTLE_SEED,
		"p1_control_mode": CONTROL_MODE_MANUAL,
		"p2_control_mode": CONTROL_MODE_POLICY,
		"demo_profile_id": "",
	}

func build_summary_context(launch_config: Dictionary, control_modes: Dictionary, command_steps: int) -> Dictionary:
	# 把 launch_config + side_modes + command_steps 聚合成 sandbox / demo summary
	# 的稳定字段集；缺省值由本 launch_config 模块的常量统一兜底。
	return {
		"matchup_id": str(launch_config.get("matchup_id", DEFAULT_MATCHUP_ID)).strip_edges(),
		"battle_seed": int(launch_config.get("battle_seed", DEFAULT_BATTLE_SEED)),
		"p1_control_mode": str(control_modes.get("P1", CONTROL_MODE_MANUAL)).strip_edges(),
		"p2_control_mode": str(control_modes.get("P2", CONTROL_MODE_MANUAL)).strip_edges(),
		"command_steps": int(command_steps),
	}

func build_config_from_user_args(user_args: Array) -> Dictionary:
	var config := default_config()
	config[STRICT_CONFIG_KEY] = true
	for raw_arg in user_args:
		var arg := str(raw_arg).strip_edges()
		if arg.is_empty() or not arg.contains("="):
			continue
		var pair := arg.split("=", true, 1)
		var key := str(pair[0]).strip_edges()
		var value := str(pair[1]).strip_edges()
		match key:
			"demo":
				config["mode"] = MODE_DEMO_REPLAY
				config["demo_profile_id"] = value
			"matchup":
				config["matchup_id"] = value
			"battle_seed", "seed":
				config["battle_seed"] = value
			"p1_mode":
				config["p1_control_mode"] = value
			"p2_mode":
				config["p2_control_mode"] = value
	return config

func normalize_config(raw_config: Dictionary, available_matchups: Array = []) -> Dictionary:
	var result := normalize_config_result(raw_config, available_matchups, false)
	if bool(result.get("ok", false)):
		return result.get("data", default_config()).duplicate(true)
	return default_config()

func normalize_config_result(raw_config: Dictionary, available_matchups: Array = [], strict: bool = false) -> Dictionary:
	var normalized := default_config()
	for key in normalized.keys():
		if raw_config.has(key):
			normalized[key] = raw_config.get(key)
	var errors: Array[String] = []
	var visible_matchups := visible_matchup_descriptors(available_matchups)
	var fallback_matchup_id := DEFAULT_MATCHUP_ID
	if not visible_matchups.is_empty():
		fallback_matchup_id = str(visible_matchups[0].get("matchup_id", DEFAULT_MATCHUP_ID)).strip_edges()
	var allowed_matchups: Dictionary = {}
	for descriptor in visible_matchups:
		if not (descriptor is Dictionary):
			continue
		var descriptor_matchup_id := str(descriptor.get("matchup_id", "")).strip_edges()
		if descriptor_matchup_id.is_empty():
			continue
		allowed_matchups[descriptor_matchup_id] = true
	if allowed_matchups.has(DEFAULT_MATCHUP_ID):
		fallback_matchup_id = DEFAULT_MATCHUP_ID
	var mode := str(normalized.get("mode", MODE_MANUAL_MATCHUP)).strip_edges()
	var demo_profile_id := str(normalized.get("demo_profile_id", "")).strip_edges()
	if not demo_profile_id.is_empty():
		mode = MODE_DEMO_REPLAY
	elif mode != MODE_MANUAL_MATCHUP:
		if strict:
			errors.append("invalid sandbox mode: %s" % mode)
		mode = MODE_MANUAL_MATCHUP
	var matchup_id := str(normalized.get("matchup_id", fallback_matchup_id)).strip_edges()
	if mode == MODE_DEMO_REPLAY:
		if matchup_id.is_empty():
			matchup_id = fallback_matchup_id
	elif matchup_id.is_empty() or not allowed_matchups.has(matchup_id):
		if strict:
			errors.append("unknown sandbox matchup_id: %s" % matchup_id)
		matchup_id = fallback_matchup_id
	normalized["mode"] = mode
	normalized["demo_profile_id"] = demo_profile_id
	normalized["matchup_id"] = matchup_id
	var seed_result := _normalize_battle_seed_result(normalized.get("battle_seed", DEFAULT_BATTLE_SEED), strict)
	if not bool(seed_result.get("ok", false)):
		errors.append(String(seed_result.get(ERROR_MESSAGE_KEY, "invalid battle_seed")))
	normalized["battle_seed"] = int(seed_result.get("data", DEFAULT_BATTLE_SEED))
	for side_key in ["p1_control_mode", "p2_control_mode"]:
		var raw_control_mode := str(normalized.get(side_key, CONTROL_MODE_MANUAL))
		var control_mode_result := normalize_control_mode_result(raw_control_mode, strict)
		if not bool(control_mode_result.get("ok", false)):
			errors.append(String(control_mode_result.get(ERROR_MESSAGE_KEY, "invalid control mode")))
		normalized[side_key] = String(control_mode_result.get("data", CONTROL_MODE_MANUAL))
	if strict and not errors.is_empty():
		return {
			"ok": false,
			"data": normalized,
			"error_message": "; ".join(errors),
		}
	return {
		"ok": true,
		"data": normalized,
		"error_message": "",
	}

func visible_matchup_descriptors(available_matchups: Array) -> Array:
	var recommended_ids := recommended_matchup_ids()
	var visible_by_id: Dictionary = {}
	var remaining_visible: Array = []
	var visible: Array = []
	for raw_descriptor in available_matchups:
		if not (raw_descriptor is Dictionary):
			continue
		var descriptor: Dictionary = raw_descriptor.duplicate(true)
		if bool(descriptor.get("test_only", false)):
			continue
		var matchup_id := str(descriptor.get("matchup_id", "")).strip_edges()
		if matchup_id.is_empty():
			continue
		if recommended_ids.has(matchup_id):
			visible_by_id[matchup_id] = descriptor
			continue
		remaining_visible.append(descriptor)
	for matchup_id in recommended_ids:
		if visible_by_id.has(matchup_id):
			visible.append(visible_by_id.get(matchup_id))
	visible.append_array(remaining_visible)
	return visible

func recommended_matchup_ids() -> Array[String]:
	var recommended_ids: Array[String] = []
	var seen_ids: Dictionary = {}
	var entries_result: Dictionary = _manifest.build_runtime_entries_result()
	if bool(entries_result.get("ok", false)):
		for raw_entry in entries_result.get("data", []):
			if not (raw_entry is Dictionary):
				continue
			_append_unique_matchup_id(
				recommended_ids,
				seen_ids,
				String(raw_entry.get("formal_setup_matchup_id", "")).strip_edges()
			)
	_append_unique_matchup_id(recommended_ids, seen_ids, SAMPLE_DEFAULT_MATCHUP_ID)
	return recommended_ids

func _append_unique_matchup_id(matchup_ids: Array[String], seen_ids: Dictionary, matchup_id: String) -> void:
	if matchup_id.is_empty() or seen_ids.has(matchup_id):
		return
	seen_ids[matchup_id] = true
	matchup_ids.append(matchup_id)

func side_control_modes(config: Dictionary) -> Dictionary:
	return {
		"P1": normalize_control_mode(str(config.get("p1_control_mode", CONTROL_MODE_MANUAL))),
		"P2": normalize_control_mode(str(config.get("p2_control_mode", CONTROL_MODE_MANUAL))),
	}

func normalize_control_mode(raw_control_mode: String) -> String:
	var result := normalize_control_mode_result(raw_control_mode, false)
	return String(result.get("data", CONTROL_MODE_MANUAL))

func normalize_control_mode_result(raw_control_mode: String, strict: bool = false) -> Dictionary:
	var control_mode := raw_control_mode.strip_edges()
	if control_mode == CONTROL_MODE_POLICY or control_mode == CONTROL_MODE_MANUAL:
		return {"ok": true, "data": control_mode, "error_message": ""}
	if strict:
		return {"ok": false, "data": CONTROL_MODE_MANUAL, "error_message": "invalid sandbox control mode: %s" % control_mode}
	return {"ok": true, "data": CONTROL_MODE_MANUAL, "error_message": ""}

func is_policy_control_mode(raw_control_mode: String) -> bool:
	return normalize_control_mode(raw_control_mode) == CONTROL_MODE_POLICY

func build_config_summary(config: Dictionary) -> String:
	return "matchup=%s | seed=%d | P1=%s | P2=%s" % [
		str(config.get("matchup_id", DEFAULT_MATCHUP_ID)).strip_edges(),
		int(config.get("battle_seed", DEFAULT_BATTLE_SEED)),
		normalize_control_mode(str(config.get("p1_control_mode", CONTROL_MODE_MANUAL))),
		normalize_control_mode(str(config.get("p2_control_mode", CONTROL_MODE_MANUAL))),
	]

func _normalize_battle_seed(raw_battle_seed) -> int:
	return int(_normalize_battle_seed_result(raw_battle_seed, false).get("data", DEFAULT_BATTLE_SEED))

func _normalize_battle_seed_result(raw_battle_seed, strict: bool = false) -> Dictionary:
	if typeof(raw_battle_seed) == TYPE_INT and int(raw_battle_seed) > 0:
		return {"ok": true, "data": int(raw_battle_seed), "error_message": ""}
	if typeof(raw_battle_seed) == TYPE_FLOAT:
		var float_value := float(raw_battle_seed)
		var int_value := int(float_value)
		if float_value == float(int_value) and int_value > 0:
			return {"ok": true, "data": int_value, "error_message": ""}
	var parsed_value := _parse_positive_int(str(raw_battle_seed), -1)
	if parsed_value > 0:
		return {"ok": true, "data": parsed_value, "error_message": ""}
	if strict:
		return {"ok": false, "data": DEFAULT_BATTLE_SEED, "error_message": "invalid sandbox battle_seed: %s" % str(raw_battle_seed)}
	return {"ok": true, "data": DEFAULT_BATTLE_SEED, "error_message": ""}

func _parse_positive_int(raw_value: String, fallback: int) -> int:
	var trimmed_value := raw_value.strip_edges()
	if trimmed_value.is_empty():
		return fallback
	var parsed_value := int(trimmed_value.to_int())
	if parsed_value > 0:
		return parsed_value
	return fallback
