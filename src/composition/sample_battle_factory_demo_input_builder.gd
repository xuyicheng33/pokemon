extends RefCounted
class_name SampleBattleFactoryDemoInputBuilder

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentPathsHelperScript := preload("res://src/composition/sample_battle_factory_content_paths_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

var baseline_matchup_catalog: SampleBattleFactoryBaselineMatchupCatalog = null
var content_paths_helper: SampleBattleFactoryContentPathsHelper = null
var demo_catalog: SampleBattleFactoryDemoCatalog = null
var setup_access: SampleBattleFactorySetupAccess = null

func build_demo_replay_input_result(command_port, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var default_profile_result: Dictionary = demo_catalog.default_profile_id_result()
	if not bool(default_profile_result.get("ok", false)):
		return default_profile_result
	return build_demo_replay_input_for_profile_result(
		command_port,
		String(default_profile_result.get("data", "")).strip_edges(),
		side_regular_skill_overrides
	)

func build_demo_replay_input_for_profile_result(command_port, demo_profile_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var profile_result: Dictionary = demo_catalog.profile_result(demo_profile_id)
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var profile: Dictionary = profile_result.get("data", {})
	var matchup_id := String(profile.get("matchup_id", "")).strip_edges()
	var battle_setup_result: Dictionary = setup_access.build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides)
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
	return build_replay_input_result(
		command_port,
		snapshot_paths_result,
		battle_setup,
		int(profile.get("battle_seed", null)),
		profile.get("commands", null)
	)

func build_passive_item_demo_replay_input_result(command_port) -> Dictionary:
	var battle_setup_result: Dictionary = setup_access.build_setup_by_matchup_id_result("passive_item_vs_sample")
	if not bool(battle_setup_result.get("ok", false)):
		return battle_setup_result
	var snapshot_paths_result: Dictionary = content_paths_helper.build_base_snapshot_paths(
		ContentPathsHelperScript.BASE_CONTENT_SNAPSHOT_DIRS
	)
	if not bool(snapshot_paths_result.get("ok", false)):
		return snapshot_paths_result
	return _build_passive_item_demo_replay_input_from_snapshot_result(
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

func _build_passive_item_demo_replay_input_from_snapshot_result(command_port, snapshot_paths_result: Dictionary, battle_setup) -> Dictionary:
	return build_replay_input_result(
		command_port,
		snapshot_paths_result,
		battle_setup,
		1901,
		[
			{
				"turn_index": 1,
				"command_type": CommandTypesScript.SKILL,
				"command_source": "manual",
				"side_id": "P1",
				"actor_public_id": "P1-A",
				"skill_id": "sample_strike",
			},
			{
				"turn_index": 1,
				"command_type": CommandTypesScript.WAIT,
				"command_source": "manual",
				"side_id": "P2",
				"actor_public_id": "P2-A",
			},
		]
	)

func build_replay_input_result(
	command_port,
	snapshot_paths_result: Dictionary,
	battle_setup,
	battle_seed: int,
	command_payloads: Array
) -> Dictionary:
	if command_port == null or not command_port.has_method("build_command"):
		return _error_result(
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			"SampleBattleFactory replay builder requires command_port.build_command"
		)
	if not bool(snapshot_paths_result.get("ok", false)):
		return _error_result(
			str(snapshot_paths_result.get("error_code", ErrorCodesScript.INVALID_CONTENT_SNAPSHOT)),
			String(snapshot_paths_result.get("error_message", "content snapshot path build failed"))
		)
	if battle_setup == null:
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory replay input requires battle_setup"
		)
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = battle_seed
	replay_input.content_snapshot_paths = snapshot_paths_result.get("data", PackedStringArray())
	replay_input.battle_setup = battle_setup
	replay_input.command_stream = []
	for command_payload in command_payloads:
		var command_result := _resolve_command_data_result(command_port.build_command(command_payload))
		if not bool(command_result.get("ok", false)):
			return command_result
		replay_input.command_stream.append(command_result.get("data", null))
	return ResultEnvelopeHelperScript.ok(replay_input)

func _resolve_command_data_result(command_result) -> Dictionary:
	if typeof(command_result) == TYPE_DICTIONARY and command_result.has("ok") and command_result.has("data"):
		if not bool(command_result.get("ok", false)):
			return _error_result(
				str(command_result.get("error_code", ErrorCodesScript.INVALID_COMMAND_PAYLOAD)),
				String(command_result.get("error_message", "SampleBattleFactory failed to build replay command"))
			)
		var command_data = command_result.get("data", null)
		if command_data == null:
			return _error_result(
				ErrorCodesScript.INVALID_COMMAND_PAYLOAD,
				"SampleBattleFactory replay command builder returned null command"
			)
		return ResultEnvelopeHelperScript.ok(command_data)
	if command_result == null:
		return _error_result(
			ErrorCodesScript.INVALID_COMMAND_PAYLOAD,
			"SampleBattleFactory replay builder received null command"
		)
	return ResultEnvelopeHelperScript.ok(command_result)

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)
