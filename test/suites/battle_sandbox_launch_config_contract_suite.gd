extends GdUnitTestSuite

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _manifest = FormalCharacterManifestScript.new()
var _sample_factory = SampleBattleFactoryScript.new()

func after() -> void:
	if _sample_factory != null and _sample_factory.has_method("dispose"):
		_sample_factory.dispose()
	_sample_factory = null

func test_launch_config_default_config_contract() -> void:
	var launch_config: Dictionary = _launch_config_helper.default_config()
	assert_str(String(launch_config.get("mode", ""))).is_equal(BattleSandboxLaunchConfigScript.MODE_MANUAL_MATCHUP)
	assert_str(String(launch_config.get("matchup_id", ""))).is_equal("gojo_vs_sample")
	assert_int(int(launch_config.get("battle_seed", 0))).is_equal(9101)
	assert_str(String(launch_config.get("p1_control_mode", ""))).is_equal("manual")
	assert_str(String(launch_config.get("p2_control_mode", ""))).is_equal("policy")
	assert_str(String(launch_config.get("demo_profile_id", ""))).is_equal("")

func test_launch_config_user_args_are_strict_contract() -> void:
	var launch_config: Dictionary = _launch_config_helper.build_config_from_user_args([])
	assert_bool(bool(launch_config.get(BattleSandboxLaunchConfigScript.STRICT_CONFIG_KEY, false))).is_true()

func test_launch_config_user_args_preserve_invalid_seed_for_strict_validation() -> void:
	var bad_seed_config: Dictionary = _launch_config_helper.build_config_from_user_args(["seed=bad"])
	var bad_seed_result: Dictionary = _launch_config_helper.normalize_config_result(bad_seed_config, _available_matchups(), true)
	assert_bool(bool(bad_seed_result.get("ok", true))).is_false()
	assert_str(String(bad_seed_result.get("error_message", ""))).contains("invalid sandbox battle_seed: bad")
	var negative_seed_config: Dictionary = _launch_config_helper.build_config_from_user_args(["battle_seed=-99"])
	var negative_seed_result: Dictionary = _launch_config_helper.normalize_config_result(negative_seed_config, _available_matchups(), true)
	assert_bool(bool(negative_seed_result.get("ok", true))).is_false()
	assert_str(String(negative_seed_result.get("error_message", ""))).contains("invalid sandbox battle_seed: -99")
	var zero_seed_config: Dictionary = _launch_config_helper.build_config_from_user_args(["seed=0"])
	var zero_seed_result: Dictionary = _launch_config_helper.normalize_config_result(zero_seed_config, _available_matchups(), true)
	assert_bool(bool(zero_seed_result.get("ok", true))).is_false()
	assert_str(String(zero_seed_result.get("error_message", ""))).contains("invalid sandbox battle_seed: 0")

func test_launch_config_normalize_config_contract() -> void:
	var normalized: Dictionary = _launch_config_helper.normalize_config({
		"mode": "unsupported_mode",
		"matchup_id": "missing_matchup",
		"battle_seed": -99,
		"p1_control_mode": "???",
		"p2_control_mode": "policy",
	}, _available_matchups())
	assert_str(String(normalized.get("mode", ""))).is_equal(BattleSandboxLaunchConfigScript.MODE_MANUAL_MATCHUP)
	assert_str(String(normalized.get("matchup_id", ""))).is_equal("gojo_vs_sample")
	assert_int(int(normalized.get("battle_seed", 0))).is_equal(9101)
	assert_str(String(normalized.get("p1_control_mode", ""))).is_equal("manual")
	assert_str(String(normalized.get("p2_control_mode", ""))).is_equal("policy")

func test_launch_config_strict_invalid_config_contract() -> void:
	var result: Dictionary = _launch_config_helper.normalize_config_result({
		"mode": "unsupported_mode",
		"matchup_id": "missing_matchup",
		"battle_seed": -99,
		"p1_control_mode": "???",
		"p2_control_mode": "policy",
	}, _available_matchups(), true)
	assert_bool(bool(result.get("ok", true))).is_false()
	var error_message := String(result.get("error_message", ""))
	assert_str(error_message).contains("invalid sandbox mode")
	assert_str(error_message).contains("unknown sandbox matchup_id")
	assert_str(error_message).contains("invalid sandbox battle_seed")
	assert_str(error_message).contains("invalid sandbox control mode")

func test_launch_config_visible_matchup_recommended_order_contract() -> void:
	var visible_matchups: Array = _launch_config_helper.visible_matchup_descriptors(_available_matchups())
	var visible_ids := _matchup_ids(visible_matchups)
	var recommended_ids := _launch_config_helper.recommended_matchup_ids()
	assert_int(visible_ids.size()).is_greater_equal(recommended_ids.size())
	for index in range(recommended_ids.size()):
		assert_str(String(visible_ids[index])).is_equal(String(recommended_ids[index]))
	for descriptor in visible_matchups:
		if not (descriptor is Dictionary):
			continue
		assert_bool(bool(descriptor.get("test_only", false))).is_false()

func test_launch_config_recommended_matchups_follow_manifest_contract() -> void:
	var recommended_ids := _launch_config_helper.recommended_matchup_ids()
	var expected_ids := _expected_recommended_matchup_ids()
	assert_int(recommended_ids.size()).is_equal(expected_ids.size())
	for index in range(expected_ids.size()):
		assert_str(String(recommended_ids[index])).is_equal(String(expected_ids[index]))

func _expected_recommended_matchup_ids() -> Array:
	var expected_ids: Array = []
	var seen_ids: Dictionary = {}
	var entries_result: Dictionary = _manifest.build_runtime_entries_result()
	assert_bool(bool(entries_result.get("ok", false))).is_true()
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		_append_unique_matchup_id(
			expected_ids,
			seen_ids,
			String(raw_entry.get("formal_setup_matchup_id", "")).strip_edges()
		)
	_append_unique_matchup_id(
		expected_ids,
		seen_ids,
		BattleSandboxLaunchConfigScript.SAMPLE_DEFAULT_MATCHUP_ID
	)
	return expected_ids

func _append_unique_matchup_id(matchup_ids: Array, seen_ids: Dictionary, matchup_id: String) -> void:
	if matchup_id.is_empty() or seen_ids.has(matchup_id):
		return
	seen_ids[matchup_id] = true
	matchup_ids.append(matchup_id)

func _available_matchups() -> Array:
	var available_result: Dictionary = _sample_factory.available_matchups_result()
	assert_bool(bool(available_result.get("ok", false))).is_true()
	var available_matchups = available_result.get("data", [])
	assert_bool(available_matchups is Array).is_true()
	return available_matchups

func _matchup_ids(visible_matchups: Array) -> Array:
	var matchup_ids: Array = []
	for descriptor in visible_matchups:
		if not (descriptor is Dictionary):
			continue
		matchup_ids.append(String(descriptor.get("matchup_id", "")))
	return matchup_ids
