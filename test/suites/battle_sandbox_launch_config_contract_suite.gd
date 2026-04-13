extends GdUnitTestSuite

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _sample_factory = SampleBattleFactoryScript.new()

func test_launch_config_default_config_contract() -> void:
	var launch_config: Dictionary = _launch_config_helper.default_config()
	assert_str(String(launch_config.get("mode", ""))).is_equal(BattleSandboxLaunchConfigScript.MODE_MANUAL_MATCHUP)
	assert_str(String(launch_config.get("matchup_id", ""))).is_equal("gojo_vs_sample")
	assert_int(int(launch_config.get("battle_seed", 0))).is_equal(9101)
	assert_str(String(launch_config.get("p1_control_mode", ""))).is_equal("manual")
	assert_str(String(launch_config.get("p2_control_mode", ""))).is_equal("policy")
	assert_str(String(launch_config.get("demo_profile_id", ""))).is_equal("")

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

func test_launch_config_visible_matchup_recommended_order_contract() -> void:
	var visible_matchups: Array = _launch_config_helper.visible_matchup_descriptors(_available_matchups())
	var visible_ids := _matchup_ids(visible_matchups)
	assert_int(visible_ids.find("gojo_vs_sample")).is_equal(0)
	assert_int(visible_ids.find("kashimo_vs_sample")).is_equal(1)
	assert_int(visible_ids.find("sukuna_setup")).is_equal(2)
	assert_int(visible_ids.find("sample_default")).is_equal(3)
	for descriptor in visible_matchups:
		if not (descriptor is Dictionary):
			continue
		assert_bool(bool(descriptor.get("test_only", false))).is_false()

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
