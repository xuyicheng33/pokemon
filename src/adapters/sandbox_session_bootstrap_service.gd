extends RefCounted
class_name SandboxSessionBootstrapService

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

var launch_config_helper: BattleSandboxLaunchConfig = BattleSandboxLaunchConfigScript.new()
var command_service: SandboxSessionCommandService = null

func prepare_scene(state: SandboxSessionState, requested_config: Dictionary) -> String:
	var compose_error = _compose_dependencies(state)
	if not compose_error.is_empty():
		return compose_error
	var available_matchups_error = _load_available_matchups(state)
	if not available_matchups_error.is_empty():
		return available_matchups_error
	var strict_config := bool(requested_config.get(BattleSandboxLaunchConfigScript.STRICT_CONFIG_KEY, false))
	var launch_config_result := launch_config_helper.normalize_config_result(requested_config, state.available_matchups, strict_config)
	if not bool(launch_config_result.get("ok", false)):
		return "Battle sandbox invalid launch config: %s" % str(launch_config_result.get("error_message", "unknown config error"))
	state.launch_config = launch_config_result.get("data", {}).duplicate(true)
	state.side_control_modes = launch_config_helper.side_control_modes(state.launch_config)
	state.is_demo_mode = str(state.launch_config.get("mode", "")).strip_edges() == BattleSandboxLaunchConfigScript.MODE_DEMO_REPLAY
	state.demo_profile = str(state.launch_config.get("demo_profile_id", "")).strip_edges()
	if state.is_demo_mode:
		return ""
	return create_session_for_launch_config(state)

func reset_state(state: SandboxSessionState) -> void:
	var default_launch_config := launch_config_helper.default_config()
	state.reset(default_launch_config, launch_config_helper.side_control_modes(default_launch_config))

func close_session_if_needed(state: SandboxSessionState) -> Dictionary:
	if state.manager == null or str(state.session_id).strip_edges().is_empty():
		return ResultEnvelopeHelperScript.ok({"closed": false})
	var close_result: Dictionary = state.manager.close_session(state.session_id)
	if bool(close_result.get("ok", false)):
		state.session_id = ""
	return close_result

func dispose_manager(state: SandboxSessionState) -> void:
	if state.manager != null:
		state.manager.dispose()
	if state.sample_factory != null:
		state.sample_factory.dispose()
	state.manager = null
	state.composer = null
	state.sample_factory = null

func create_session_for_launch_config(state: SandboxSessionState) -> String:
	if command_service == null:
		return "Sandbox bootstrap requires command_service"
	var matchup_id = str(state.launch_config.get("matchup_id", BattleSandboxLaunchConfigScript.DEFAULT_MATCHUP_ID)).strip_edges()
	var setup_result: Dictionary = state.sample_factory.build_setup_by_matchup_id_result(matchup_id)
	if not bool(setup_result.get("ok", false)):
		return "Battle sandbox failed to build matchup %s: %s" % [
			matchup_id,
			str(setup_result.get("error_message", "unknown error")),
		]
	state.battle_setup = setup_result.get("data", {})
	if state.battle_setup == null:
		return "Battle sandbox received empty battle_setup for %s" % matchup_id
	var snapshot_paths_result: Dictionary = state.sample_factory.content_snapshot_paths_for_setup_result(state.battle_setup)
	if not bool(snapshot_paths_result.get("ok", false)):
		return "Battle sandbox failed to resolve setup snapshot paths: %s" % str(snapshot_paths_result.get("error_message", "unknown error"))
	var create_unwrap: Dictionary = command_service.envelope.unwrap_ok(
		state.manager.create_session({
			"battle_seed": int(state.launch_config.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)),
			"content_snapshot_paths": snapshot_paths_result.get("data", PackedStringArray()),
			"battle_setup": state.battle_setup,
		}),
		"create_session(%s)" % matchup_id
	)
	if not bool(create_unwrap.get("ok", false)):
		return str(create_unwrap.get("error_message", "Battle sandbox create_session failed"))
	state.session_id = str(create_unwrap.get("data", {}).get("session_id", "")).strip_edges()
	if state.session_id.is_empty():
		return "Battle sandbox create_session returned empty session_id"
	var refresh_error = command_service.refresh_session_snapshot_and_logs(state, 0)
	if not refresh_error.is_empty():
		return refresh_error
	state.current_side_to_select = command_service.primary_side_id()
	var p1_legal_unwrap: Dictionary = command_service.refresh_legal_actions_for_side(state, state.current_side_to_select)
	if not bool(p1_legal_unwrap.get("ok", false)):
		return str(p1_legal_unwrap.get("error_message", "Battle sandbox failed to get initial legal actions"))
	return ""

func _compose_dependencies(state: SandboxSessionState) -> String:
	state.composer = BattleCoreComposerScript.new()
	if state.composer == null:
		return "Battle sandbox failed to construct composer"
	state.manager = state.composer.compose_manager()
	if state.manager == null:
		var composer_error: Dictionary = state.composer.error_state()
		return "Battle sandbox failed to compose manager: %s" % str(composer_error.get("message", "unknown composition error"))
	state.sample_factory = SampleBattleFactoryScript.new()
	if state.sample_factory == null:
		return "Battle sandbox failed to construct sample battle factory"
	return ""

func _load_available_matchups(state: SandboxSessionState) -> String:
	var available_result: Dictionary = state.sample_factory.available_matchups_result()
	if not bool(available_result.get("ok", false)):
		return "Battle sandbox failed to load available matchups: %s" % str(available_result.get("error_message", "unknown error"))
	var descriptors = available_result.get("data", [])
	if not (descriptors is Array):
		return "Battle sandbox available matchups result must be array"
	state.available_matchups = descriptors.duplicate(true)
	return ""
