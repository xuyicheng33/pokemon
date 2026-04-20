extends RefCounted
class_name BattleSandboxLaunchConfig

const MODE_MANUAL_MATCHUP := "manual_matchup"
const MODE_DEMO_REPLAY := "demo_replay"
const CONTROL_MODE_MANUAL := "manual"
const CONTROL_MODE_POLICY := "policy"
const DEFAULT_MATCHUP_ID := "gojo_vs_sample"
const DEFAULT_BATTLE_SEED := 9101
const SIDE_IDS := ["P1", "P2"]
const RECOMMENDED_MATCHUP_IDS := [
	"gojo_vs_sample",
	"kashimo_vs_sample",
	"obito_vs_sample",
	"sukuna_setup",
	"sample_default",
]

func default_config() -> Dictionary:
	return {
		"mode": MODE_MANUAL_MATCHUP,
		"matchup_id": DEFAULT_MATCHUP_ID,
		"battle_seed": DEFAULT_BATTLE_SEED,
		"p1_control_mode": CONTROL_MODE_MANUAL,
		"p2_control_mode": CONTROL_MODE_POLICY,
		"demo_profile_id": "",
	}

func build_config_from_user_args(user_args: Array) -> Dictionary:
	var config := default_config()
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
				config["battle_seed"] = _parse_positive_int(value, DEFAULT_BATTLE_SEED)
			"p1_mode":
				config["p1_control_mode"] = value
			"p2_mode":
				config["p2_control_mode"] = value
	return config

func normalize_config(raw_config: Dictionary, available_matchups: Array = []) -> Dictionary:
	var normalized := default_config()
	for key in normalized.keys():
		if raw_config.has(key):
			normalized[key] = raw_config.get(key)
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
		mode = MODE_MANUAL_MATCHUP
	var matchup_id := str(normalized.get("matchup_id", fallback_matchup_id)).strip_edges()
	if matchup_id.is_empty() or not allowed_matchups.has(matchup_id):
		matchup_id = fallback_matchup_id
	normalized["mode"] = mode
	normalized["demo_profile_id"] = demo_profile_id
	normalized["matchup_id"] = matchup_id
	normalized["battle_seed"] = _normalize_battle_seed(normalized.get("battle_seed", DEFAULT_BATTLE_SEED))
	normalized["p1_control_mode"] = normalize_control_mode(str(normalized.get("p1_control_mode", CONTROL_MODE_MANUAL)))
	normalized["p2_control_mode"] = normalize_control_mode(str(normalized.get("p2_control_mode", CONTROL_MODE_MANUAL)))
	return normalized

func visible_matchup_descriptors(available_matchups: Array) -> Array:
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
		if RECOMMENDED_MATCHUP_IDS.has(matchup_id):
			visible_by_id[matchup_id] = descriptor
			continue
		remaining_visible.append(descriptor)
	for matchup_id in RECOMMENDED_MATCHUP_IDS:
		if visible_by_id.has(matchup_id):
			visible.append(visible_by_id.get(matchup_id))
	visible.append_array(remaining_visible)
	return visible

func side_control_modes(config: Dictionary) -> Dictionary:
	return {
		"P1": normalize_control_mode(str(config.get("p1_control_mode", CONTROL_MODE_MANUAL))),
		"P2": normalize_control_mode(str(config.get("p2_control_mode", CONTROL_MODE_MANUAL))),
	}

func normalize_control_mode(raw_control_mode: String) -> String:
	var control_mode := raw_control_mode.strip_edges()
	if control_mode == CONTROL_MODE_POLICY:
		return CONTROL_MODE_POLICY
	return CONTROL_MODE_MANUAL

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
	if typeof(raw_battle_seed) == TYPE_INT and int(raw_battle_seed) > 0:
		return int(raw_battle_seed)
	if typeof(raw_battle_seed) == TYPE_FLOAT:
		var float_value := float(raw_battle_seed)
		var int_value := int(float_value)
		if float_value == float(int_value) and int_value > 0:
			return int_value
	return _parse_positive_int(str(raw_battle_seed), DEFAULT_BATTLE_SEED)

func _parse_positive_int(raw_value: String, fallback: int) -> int:
	var trimmed_value := raw_value.strip_edges()
	if trimmed_value.is_empty():
		return fallback
	var parsed_value := int(trimmed_value.to_int())
	if parsed_value > 0:
		return parsed_value
	return fallback
