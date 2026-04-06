extends RefCounted
class_name SampleBattleFactoryReplayBuilder

const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func build_demo_replay_input(command_port, snapshot_paths_result: Dictionary, battle_setup) -> Variant:
	return _build_replay_input(
		command_port,
		snapshot_paths_result,
		battle_setup,
		17,
		[
			{
				"turn_index": 1,
				"command_type": CommandTypesScript.SKILL,
				"command_source": "manual",
				"side_id": "P1",
				"actor_public_id": "P1-A",
				"skill_id": "sample_field_call",
			},
			{
				"turn_index": 1,
				"command_type": CommandTypesScript.SKILL,
				"command_source": "manual",
				"side_id": "P2",
				"actor_public_id": "P2-A",
				"skill_id": "sample_strike",
			},
			{
				"turn_index": 2,
				"command_type": CommandTypesScript.SKILL,
				"command_source": "manual",
				"side_id": "P1",
				"actor_public_id": "P1-A",
				"skill_id": "sample_strike",
			},
			{
				"turn_index": 2,
				"command_type": CommandTypesScript.SKILL,
				"command_source": "manual",
				"side_id": "P2",
				"actor_public_id": "P2-A",
				"skill_id": "sample_whiff",
			},
		]
	)

func build_passive_item_demo_replay_input(command_port, snapshot_paths_result: Dictionary, battle_setup) -> Variant:
	return _build_replay_input(
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

func _build_replay_input(
	command_port,
	snapshot_paths_result: Dictionary,
	battle_setup,
	battle_seed: int,
	command_payloads: Array
) -> Variant:
	if command_port == null or not command_port.has_method("build_command"):
		return null
	if not bool(snapshot_paths_result.get("ok", false)):
		return null
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = battle_seed
	replay_input.content_snapshot_paths = snapshot_paths_result.get("data", PackedStringArray())
	replay_input.battle_setup = battle_setup
	replay_input.command_stream = []
	for command_payload in command_payloads:
		replay_input.command_stream.append(_resolve_command_data(command_port.build_command(command_payload)))
	return replay_input

func _resolve_command_data(command_result) -> Variant:
	if typeof(command_result) == TYPE_DICTIONARY and command_result.has("ok") and command_result.has("data"):
		return command_result.get("data", null)
	return command_result
