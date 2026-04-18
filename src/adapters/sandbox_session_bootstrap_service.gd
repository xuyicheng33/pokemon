extends RefCounted
class_name SandboxSessionBootstrapService

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")

var launch_config_helper = BattleSandboxLaunchConfigScript.new()
var command_service = null

func prepare_scene(controller, requested_config: Dictionary) -> String:
	var compose_error = _compose_dependencies(controller)
	if not compose_error.is_empty():
		return compose_error
	var available_matchups_error = _load_available_matchups(controller)
	if not available_matchups_error.is_empty():
		return available_matchups_error
	controller.launch_config = launch_config_helper.normalize_config(requested_config, controller.available_matchups)
	controller.side_control_modes = launch_config_helper.side_control_modes(controller.launch_config)
	controller.is_demo_mode = str(controller.launch_config.get("mode", "")).strip_edges() == BattleSandboxLaunchConfigScript.MODE_DEMO_REPLAY
	controller.demo_profile = str(controller.launch_config.get("demo_profile_id", "")).strip_edges()
	if controller.is_demo_mode:
		return ""
	return create_session_for_launch_config(controller)

func reset_state(controller) -> void:
	controller.session_id = ""
	controller.battle_setup = null
	controller.public_snapshot = {}
	controller.legal_actions_by_side.clear()
	controller.pending_commands.clear()
	controller.current_side_to_select = ""
	controller.error_message = ""
	controller.view_model = {}
	controller.launch_config = launch_config_helper.default_config()
	controller.side_control_modes = launch_config_helper.side_control_modes(controller.launch_config)
	controller.available_matchups.clear()
	controller.demo_profile = ""
	controller.is_demo_mode = false
	controller.command_steps = 0
	controller._event_log_buffer.reset()

func close_session_if_needed(controller) -> void:
	if controller.manager == null or str(controller.session_id).strip_edges().is_empty():
		return
	controller.manager.close_session(controller.session_id)
	controller.session_id = ""

func dispose_manager(controller) -> void:
	if controller.manager != null and controller.manager.has_method("dispose"):
		controller.manager.dispose()
	controller.manager = null
	controller.composer = null
	controller.sample_factory = null

func create_session_for_launch_config(controller) -> String:
	if command_service == null:
		return "Sandbox bootstrap requires command_service"
	var matchup_id = str(controller.launch_config.get("matchup_id", BattleSandboxLaunchConfigScript.DEFAULT_MATCHUP_ID)).strip_edges()
	var setup_result: Dictionary = controller.sample_factory.build_setup_by_matchup_id_result(matchup_id)
	if not bool(setup_result.get("ok", false)):
		return "Battle sandbox failed to build matchup %s: %s" % [
			matchup_id,
			str(setup_result.get("error_message", "unknown error")),
		]
	controller.battle_setup = setup_result.get("data", {})
	if controller.battle_setup == null:
		return "Battle sandbox received empty battle_setup for %s" % matchup_id
	var snapshot_paths_result: Dictionary = controller.sample_factory.content_snapshot_paths_for_setup_result(controller.battle_setup)
	if not bool(snapshot_paths_result.get("ok", false)):
		return "Battle sandbox failed to resolve setup snapshot paths: %s" % str(snapshot_paths_result.get("error_message", "unknown error"))
	var create_unwrap: Dictionary = command_service.envelope.unwrap_ok(
		controller.manager.create_session({
			"battle_seed": int(controller.launch_config.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)),
			"content_snapshot_paths": snapshot_paths_result.get("data", PackedStringArray()),
			"battle_setup": controller.battle_setup,
		}),
		"create_session(%s)" % matchup_id
	)
	if not bool(create_unwrap.get("ok", false)):
		return str(create_unwrap.get("error", "Battle sandbox create_session failed"))
	controller.session_id = str(create_unwrap.get("data", {}).get("session_id", "")).strip_edges()
	if controller.session_id.is_empty():
		return "Battle sandbox create_session returned empty session_id"
	var refresh_error = command_service.refresh_session_snapshot_and_logs(controller, 0)
	if not refresh_error.is_empty():
		return refresh_error
	controller.current_side_to_select = command_service.primary_side_id()
	var p1_legal_unwrap: Dictionary = command_service.refresh_legal_actions_for_side(controller, controller.current_side_to_select)
	if not bool(p1_legal_unwrap.get("ok", false)):
		return str(p1_legal_unwrap.get("error", "Battle sandbox failed to get initial legal actions"))
	return ""

func _compose_dependencies(controller) -> String:
	controller.composer = BattleCoreComposerScript.new()
	if controller.composer == null:
		return "Battle sandbox failed to construct composer"
	controller.manager = controller.composer.compose_manager()
	if controller.manager == null:
		var composer_error: Dictionary = controller.composer.error_state()
		return "Battle sandbox failed to compose manager: %s" % str(composer_error.get("message", "unknown composition error"))
	controller.sample_factory = SampleBattleFactoryScript.new()
	if controller.sample_factory == null:
		return "Battle sandbox failed to construct sample battle factory"
	return ""

func _load_available_matchups(controller) -> String:
	var available_result: Dictionary = controller.sample_factory.available_matchups_result()
	if not bool(available_result.get("ok", false)):
		return "Battle sandbox failed to load available matchups: %s" % str(available_result.get("error_message", "unknown error"))
	var descriptors = available_result.get("data", [])
	if not (descriptors is Array):
		return "Battle sandbox available matchups result must be array"
	controller.available_matchups = descriptors.duplicate(true)
	return ""
