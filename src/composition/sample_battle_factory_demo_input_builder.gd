extends RefCounted
class_name SampleBattleFactoryDemoInputBuilder

const ContentPathsHelperScript := preload("res://src/composition/sample_battle_factory_content_paths_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var baseline_matchup_catalog
var content_paths_helper
var demo_catalog
var replay_builder

func build_demo_replay_input_result(sample_factory, command_port, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var default_profile_result: Dictionary = demo_catalog.default_profile_id_result()
	if not bool(default_profile_result.get("ok", false)):
		return default_profile_result
	return build_demo_replay_input_for_profile_result(
		sample_factory,
		command_port,
		String(default_profile_result.get("data", "")).strip_edges(),
		side_regular_skill_overrides
	)

func build_demo_replay_input_for_profile_result(
	sample_factory,
	command_port,
	demo_profile_id: String,
	side_regular_skill_overrides: Dictionary = {}
) -> Dictionary:
	var profile_result: Dictionary = demo_catalog.profile_result(demo_profile_id)
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var profile: Dictionary = profile_result.get("data", {})
	var matchup_id := String(profile.get("matchup_id", "")).strip_edges()
	var battle_setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides)
	if not bool(battle_setup_result.get("ok", false)):
		return _error_result(
			str(battle_setup_result.get("error_code", ErrorCodesScript.INVALID_BATTLE_SETUP)),
			"SampleBattleFactory demo replay profile[%s] failed to build matchup %s: %s" % [
				demo_profile_id,
				matchup_id,
				String(battle_setup_result.get("error_message", "unknown error")),
			]
		)
	var battle_setup = battle_setup_result.get("data", null)
	var snapshot_paths_result := _build_snapshot_paths_result(matchup_id, battle_setup)
	if not bool(snapshot_paths_result.get("ok", false)):
		return snapshot_paths_result
	return replay_builder.build_replay_input_result(
		command_port,
		snapshot_paths_result,
		battle_setup,
		int(profile.get("battle_seed", null)),
		profile.get("commands", null)
	)

func build_passive_item_demo_replay_input_result(sample_factory, command_port) -> Dictionary:
	var battle_setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result("passive_item_vs_sample")
	if not bool(battle_setup_result.get("ok", false)):
		return battle_setup_result
	var snapshot_paths_result: Dictionary = content_paths_helper.build_base_snapshot_paths(
		ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS
	)
	if not bool(snapshot_paths_result.get("ok", false)):
		return snapshot_paths_result
	return replay_builder.build_passive_item_demo_replay_input_result(
		command_port,
		snapshot_paths_result,
		battle_setup_result.get("data", null)
	)

func _build_snapshot_paths_result(matchup_id: String, battle_setup) -> Dictionary:
	if baseline_matchup_catalog.has_matchup(matchup_id):
		return content_paths_helper.build_base_snapshot_paths(ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS)
	return content_paths_helper.build_snapshot_paths_for_setup(
		ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS,
		battle_setup
	)

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
