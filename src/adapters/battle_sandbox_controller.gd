extends Control
class_name BattleSandboxController

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")
const BattleUIViewModelBuilderScript := preload("res://src/adapters/battle_ui_view_model_builder.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const BattleSandboxFirstLegalPolicyScript := preload("res://src/adapters/battle_sandbox_first_legal_policy.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

const SIDE_ORDER := ["P1", "P2"]
const MAX_EVENT_LINES := 24
const MAX_POLICY_COMMAND_STEPS := 256

@onready var _status_label: Label = $RootMargin/MainColumn/HeaderPanel/HeaderContent/StatusLabel
@onready var _error_label: Label = $RootMargin/MainColumn/HeaderPanel/HeaderContent/ErrorLabel
@onready var _battle_summary_label: Label = $RootMargin/MainColumn/HeaderPanel/HeaderContent/BattleSummaryLabel
@onready var _p1_summary: RichTextLabel = $RootMargin/MainColumn/BodyRow/P1Panel/P1Content/P1Summary
@onready var _event_log_text: RichTextLabel = $RootMargin/MainColumn/BodyRow/EventPanel/EventContent/EventLogText
@onready var _p2_summary: RichTextLabel = $RootMargin/MainColumn/BodyRow/P2Panel/P2Content/P2Summary
@onready var _config_status_label: Label = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigStatusLabel
@onready var _matchup_select: OptionButton = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/MatchupSelect
@onready var _battle_seed_input: LineEdit = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/BattleSeedInput
@onready var _p1_mode_select: OptionButton = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/P1ModeSelect
@onready var _p2_mode_select: OptionButton = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/P2ModeSelect
@onready var _action_header_label: Label = $RootMargin/MainColumn/ActionPanel/ActionContent/ActionHeaderLabel
@onready var _pending_label: Label = $RootMargin/MainColumn/ActionPanel/ActionContent/PendingLabel
@onready var _primary_buttons: HBoxContainer = $RootMargin/MainColumn/ActionPanel/ActionContent/PrimaryButtons
@onready var _switch_label: Label = $RootMargin/MainColumn/ActionPanel/ActionContent/SwitchLabel
@onready var _switch_buttons: HBoxContainer = $RootMargin/MainColumn/ActionPanel/ActionContent/SwitchButtons
@onready var _utility_buttons: HBoxContainer = $RootMargin/MainColumn/ActionPanel/ActionContent/UtilityButtons
@onready var _restart_button: Button = $RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/RestartButton

var composer = null
var manager = null
var sample_factory = null
var policy_port = BattleSandboxFirstLegalPolicyScript.new()

var session_id: String = ""
var battle_setup = null
var public_snapshot: Dictionary = {}
var event_log_cursor: int = 0
var legal_actions_by_side: Dictionary = {}
var pending_commands: Dictionary = {}
var current_side_to_select: String = ""
var recent_event_lines: Array = []
var last_event_delta: Array = []
var error_message: String = ""
var view_model: Dictionary = {}
var launch_config: Dictionary = {}
var side_control_modes: Dictionary = {}
var available_matchups: Array = []
var battle_summary: Dictionary = {}

var demo_profile: String = ""
var is_demo_mode: bool = false

var _selection_adapter = PlayerSelectionAdapterScript.new()
var _view_model_builder = BattleUIViewModelBuilderScript.new()
var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _startup_failed: bool = false

func _ready() -> void:
	_restart_button.pressed.connect(_on_restart_pressed)
	_configure_static_controls()
	bootstrap_from_environment()

func _exit_tree() -> void:
	_close_session_if_needed()
	_dispose_manager()

func build_view_model() -> Dictionary:
	return _view_model_builder.build_view_model(public_snapshot, _build_view_context())

func bootstrap_from_environment() -> Dictionary:
	return bootstrap_with_config(_launch_config_helper.build_config_from_user_args(OS.get_cmdline_user_args()))

func bootstrap_with_config(config: Dictionary) -> Dictionary:
	return _bootstrap_scene(config)

func bootstrap_manual_mode(battle_seed: int = BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED) -> Dictionary:
	var manual_config := _launch_config_helper.default_config()
	manual_config["battle_seed"] = battle_seed
	return bootstrap_with_config(manual_config)

func restart_session_with_config(config: Dictionary) -> Dictionary:
	return _bootstrap_scene(config)

func restart_manual_session(battle_seed: int = -1) -> Dictionary:
	var manual_config := launch_config.duplicate(true) if not launch_config.is_empty() else _launch_config_helper.default_config()
	manual_config["mode"] = BattleSandboxLaunchConfigScript.MODE_MANUAL_MATCHUP
	manual_config["demo_profile_id"] = ""
	if battle_seed > 0:
		manual_config["battle_seed"] = battle_seed
	return restart_session_with_config(manual_config)

func submit_selected_action(selected_action: Dictionary) -> Dictionary:
	return submit_action(selected_action)

func get_state_snapshot() -> Dictionary:
	return {
		"session_id": session_id,
		"battle_setup": battle_setup,
		"public_snapshot": public_snapshot.duplicate(true),
		"event_log_cursor": event_log_cursor,
		"current_side_to_select": current_side_to_select,
		"pending_commands": pending_commands.duplicate(),
		"legal_actions_by_side": legal_actions_by_side.duplicate(),
		"recent_event_lines": recent_event_lines.duplicate(),
		"last_event_delta": last_event_delta.duplicate(true),
		"error_message": error_message,
		"view_model": view_model.duplicate(true),
		"is_demo_mode": is_demo_mode,
		"demo_profile": demo_profile,
		"launch_config": launch_config.duplicate(true),
		"side_control_modes": side_control_modes.duplicate(true),
		"available_matchups": available_matchups.duplicate(true),
		"battle_summary": battle_summary.duplicate(true),
	}

func fetch_legal_actions_for_side(side_id: String) -> Dictionary:
	var normalized_side_id := str(side_id).strip_edges()
	if normalized_side_id.is_empty():
		return _error_result("side_id is required")
	if is_demo_mode:
		return _error_result("demo mode does not expose legal actions")
	if manager == null or session_id.is_empty():
		return _error_result("manual scene has no active session")
	var legal_actions_unwrap := _refresh_legal_actions_for_side(normalized_side_id)
	if not bool(legal_actions_unwrap.get("ok", false)):
		return legal_actions_unwrap
	_render_ui()
	return {
		"ok": true,
		"data": legal_actions_unwrap.get("data", null),
		"summary": view_model.get("legal_actions_by_side", {}).get(normalized_side_id, {}),
	}

func submit_action(selected_action: Dictionary) -> Dictionary:
	var submit_result := _submit_action_core(selected_action, "manual", true)
	_render_ui()
	return submit_result

func _bootstrap_scene(requested_config: Dictionary) -> Dictionary:
	_startup_failed = false
	error_message = ""
	_close_session_if_needed()
	_dispose_manager()
	_reset_state()
	var compose_error := _compose_dependencies()
	if not compose_error.is_empty():
		_fail_runtime(compose_error)
		return _error_result(compose_error)
	var available_matchups_error := _load_available_matchups()
	if not available_matchups_error.is_empty():
		_fail_runtime(available_matchups_error)
		return _error_result(available_matchups_error)
	launch_config = _launch_config_helper.normalize_config(requested_config, available_matchups)
	side_control_modes = _launch_config_helper.side_control_modes(launch_config)
	is_demo_mode = str(launch_config.get("mode", "")) == BattleSandboxLaunchConfigScript.MODE_DEMO_REPLAY
	demo_profile = str(launch_config.get("demo_profile_id", "")).strip_edges()
	if is_demo_mode:
		var replay_error := _run_demo_replay(demo_profile)
		if not replay_error.is_empty():
			_fail_runtime(replay_error)
			return _error_result(replay_error)
		_update_battle_summary()
		_render_ui()
		return {"ok": true, "data": get_state_snapshot()}
	var manual_error := _create_session_for_launch_config()
	if not manual_error.is_empty():
		_fail_runtime(manual_error)
		return _error_result(manual_error)
	var policy_progress_result := _advance_policy_until_manual_or_finished()
	if not bool(policy_progress_result.get("ok", false)):
		return policy_progress_result
	_render_ui()
	return {"ok": true, "data": get_state_snapshot()}

func _compose_dependencies() -> String:
	composer = BattleCoreComposerScript.new()
	if composer == null:
		return "Battle sandbox failed to construct composer"
	manager = composer.compose_manager()
	if manager == null:
		var composer_error: Dictionary = composer.error_state()
		return "Battle sandbox failed to compose manager: %s" % str(composer_error.get("message", "unknown composition error"))
	sample_factory = SampleBattleFactoryScript.new()
	if sample_factory == null:
		return "Battle sandbox failed to construct sample battle factory"
	return ""

func _load_available_matchups() -> String:
	var available_result: Dictionary = sample_factory.available_matchups_result()
	if not bool(available_result.get("ok", false)):
		return "Battle sandbox failed to load available matchups: %s" % str(available_result.get("error_message", "unknown error"))
	var descriptors = available_result.get("data", [])
	if not (descriptors is Array):
		return "Battle sandbox available matchups result must be array"
	available_matchups = descriptors.duplicate(true)
	return ""

func _run_demo_replay(profile_id: String) -> String:
	var replay_result: Dictionary = sample_factory.build_demo_replay_input_for_profile_result(manager, profile_id)
	var replay_input = _unwrap_sample_factory_result(replay_result, "%s demo replay input" % profile_id)
	if replay_input == null:
		return error_message
	var replay_unwrap := _unwrap_ok(manager.run_replay(replay_input), "run_replay(%s)" % profile_id)
	if not bool(replay_unwrap.get("ok", false)):
		return str(replay_unwrap.get("error", "Battle sandbox replay failed"))
	var replay_payload: Dictionary = replay_unwrap.get("data", {})
	public_snapshot = replay_payload.get("public_snapshot", {})
	recent_event_lines.clear()
	var replay_output = replay_payload.get("replay_output", null)
	var event_log: Array = []
	if replay_output != null:
		event_log = replay_output.event_log
	last_event_delta = event_log.duplicate(true)
	_append_event_lines(event_log)
	event_log_cursor = event_log.size()
	current_side_to_select = ""
	pending_commands.clear()
	legal_actions_by_side.clear()
	_update_battle_summary()
	return ""

func _create_session_for_launch_config() -> String:
	var matchup_id := str(launch_config.get("matchup_id", BattleSandboxLaunchConfigScript.DEFAULT_MATCHUP_ID)).strip_edges()
	var setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(matchup_id)
	if not bool(setup_result.get("ok", false)):
		return "Battle sandbox failed to build matchup %s: %s" % [
			matchup_id,
			str(setup_result.get("error_message", "unknown error")),
		]
	battle_setup = setup_result.get("data", {})
	if battle_setup == null:
		return "Battle sandbox received empty battle_setup for %s" % matchup_id
	var snapshot_paths_result: Dictionary = sample_factory.content_snapshot_paths_for_setup_result(battle_setup)
	if not bool(snapshot_paths_result.get("ok", false)):
		return "Battle sandbox failed to resolve setup snapshot paths: %s" % str(snapshot_paths_result.get("error_message", "unknown error"))
	var create_unwrap := _unwrap_ok(manager.create_session({
		"battle_seed": int(launch_config.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)),
		"content_snapshot_paths": snapshot_paths_result.get("data", PackedStringArray()),
		"battle_setup": battle_setup,
	}), "create_session(%s)" % matchup_id)
	if not bool(create_unwrap.get("ok", false)):
		return str(create_unwrap.get("error", "Battle sandbox create_session failed"))
	session_id = str(create_unwrap.get("data", {}).get("session_id", "")).strip_edges()
	if session_id.is_empty():
		return "Battle sandbox create_session returned empty session_id"
	var refresh_error := _refresh_session_snapshot_and_logs(0)
	if not refresh_error.is_empty():
		return refresh_error
	current_side_to_select = SIDE_ORDER[0]
	var p1_legal_unwrap := _refresh_legal_actions_for_side(current_side_to_select)
	if not bool(p1_legal_unwrap.get("ok", false)):
		return str(p1_legal_unwrap.get("error", "Battle sandbox failed to get initial legal actions"))
	_update_battle_summary()
	return ""

func _refresh_session_snapshot_and_logs(from_index: int) -> String:
	var snapshot_unwrap := _unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(%s)" % session_id)
	if not bool(snapshot_unwrap.get("ok", false)):
		return str(snapshot_unwrap.get("error", "Battle sandbox failed to refresh public_snapshot"))
	public_snapshot = snapshot_unwrap.get("data", {})
	var event_log_unwrap := _unwrap_ok(manager.get_event_log_snapshot(session_id, from_index), "get_event_log_snapshot(%s)" % session_id)
	if not bool(event_log_unwrap.get("ok", false)):
		return str(event_log_unwrap.get("error", "Battle sandbox failed to refresh event log"))
	var event_log_snapshot: Dictionary = event_log_unwrap.get("data", {})
	last_event_delta = event_log_snapshot.get("events", []).duplicate(true)
	_append_event_lines(last_event_delta)
	event_log_cursor = int(event_log_snapshot.get("total_size", from_index))
	_update_battle_summary()
	return ""

func _refresh_legal_actions_for_side(side_id: String) -> Dictionary:
	if side_id.is_empty():
		return {"ok": true, "data": null}
	var legal_actions_unwrap := _unwrap_ok(manager.get_legal_actions(session_id, side_id), "get_legal_actions(%s)" % side_id)
	if not bool(legal_actions_unwrap.get("ok", false)):
		return legal_actions_unwrap
	legal_actions_by_side[side_id] = legal_actions_unwrap.get("data", null)
	return legal_actions_unwrap

func _submit_action_core(selected_action: Dictionary, command_source: String, allow_policy_progression: bool) -> Dictionary:
	if is_demo_mode:
		return _error_result("demo mode does not accept manual actions")
	if _startup_failed:
		return _error_result("battle sandbox is in failed state")
	if _has_battle_result():
		return _error_result("battle already finished")
	var side_id := current_side_to_select
	if side_id.is_empty():
		return _error_result("no side is waiting for selection")
	var legal_actions = legal_actions_by_side.get(side_id, null)
	var actor_public_id := str(_read_property(legal_actions, "actor_public_id", "")).strip_edges()
	if actor_public_id.is_empty():
		return _error_result("missing actor_public_id for side %s" % side_id)
	var action_payload: Dictionary = selected_action.duplicate(true)
	action_payload["side_id"] = side_id
	action_payload["actor_public_id"] = actor_public_id
	action_payload["turn_index"] = int(public_snapshot.get("turn_index", 1))
	action_payload["command_source"] = command_source
	var command_payload: Dictionary = _selection_adapter.build_player_payload(action_payload)
	var command_unwrap := _unwrap_ok(manager.build_command(command_payload), "build_command(%s)" % side_id)
	if not bool(command_unwrap.get("ok", false)):
		_fail_runtime(str(command_unwrap.get("error", "Battle sandbox failed to build command")))
		return command_unwrap
	pending_commands[side_id] = command_unwrap.get("data", null)
	if side_id == SIDE_ORDER[0]:
		current_side_to_select = SIDE_ORDER[1]
		var refresh_unwrap := _refresh_legal_actions_for_side(current_side_to_select)
		if not bool(refresh_unwrap.get("ok", false)):
			_fail_runtime(str(refresh_unwrap.get("error", "Battle sandbox failed to refresh legal actions")))
			return refresh_unwrap
		if allow_policy_progression:
			var policy_progress_result := _advance_policy_until_manual_or_finished()
			if not bool(policy_progress_result.get("ok", false)):
				return policy_progress_result
		return {
			"ok": true,
			"data": {
				"side_id": side_id,
				"pending_commands": pending_commands.size(),
				"current_side_to_select": current_side_to_select,
			},
		}
	return _run_pending_turn(allow_policy_progression)

func _run_pending_turn(allow_policy_progression: bool) -> Dictionary:
	var commands: Array = []
	for side_id in SIDE_ORDER:
		if not pending_commands.has(side_id):
			return _error_result("missing pending command for side %s" % side_id)
		commands.append(pending_commands.get(side_id, null))
	var from_index := event_log_cursor
	var run_turn_unwrap := _unwrap_ok(manager.run_turn(session_id, commands), "run_turn(%s)" % session_id)
	if not bool(run_turn_unwrap.get("ok", false)):
		_fail_runtime(str(run_turn_unwrap.get("error", "Battle sandbox run_turn failed")))
		return run_turn_unwrap
	pending_commands.clear()
	legal_actions_by_side.clear()
	current_side_to_select = ""
	var refresh_error := _refresh_session_snapshot_and_logs(from_index)
	if not refresh_error.is_empty():
		_fail_runtime(refresh_error)
		return _error_result(refresh_error)
	if not _has_battle_result():
		current_side_to_select = SIDE_ORDER[0]
		var legal_unwrap := _refresh_legal_actions_for_side(current_side_to_select)
		if not bool(legal_unwrap.get("ok", false)):
			_fail_runtime(str(legal_unwrap.get("error", "Battle sandbox failed to refresh next turn legal actions")))
			return legal_unwrap
		if allow_policy_progression:
			var policy_progress_result := _advance_policy_until_manual_or_finished()
			if not bool(policy_progress_result.get("ok", false)):
				return policy_progress_result
	return {
		"ok": true,
		"data": {
			"event_log_cursor": event_log_cursor,
			"battle_finished": _has_battle_result(),
			"event_delta": last_event_delta.duplicate(true),
			"public_snapshot": public_snapshot.duplicate(true),
			"current_side_to_select": current_side_to_select,
			"battle_summary": battle_summary.duplicate(true),
		}
	}

func _advance_policy_until_manual_or_finished() -> Dictionary:
	var command_steps := 0
	while not _startup_failed and not is_demo_mode and not _has_battle_result():
		var side_id := str(current_side_to_select).strip_edges()
		if side_id.is_empty() or not _is_policy_side(side_id):
			return {"ok": true, "data": {"command_steps": command_steps}}
		if command_steps >= MAX_POLICY_COMMAND_STEPS:
			var limit_error := "Battle sandbox policy exceeded command step limit %d" % MAX_POLICY_COMMAND_STEPS
			_fail_runtime(limit_error)
			return _error_result(limit_error)
		var legal_actions = legal_actions_by_side.get(side_id, null)
		if legal_actions == null:
			var refresh_unwrap := _refresh_legal_actions_for_side(side_id)
			if not bool(refresh_unwrap.get("ok", false)):
				_fail_runtime(str(refresh_unwrap.get("error", "Battle sandbox failed to refresh policy legal actions")))
				return refresh_unwrap
			legal_actions = refresh_unwrap.get("data", null)
		var action_result: Dictionary = policy_port.select_action_result(legal_actions, public_snapshot.duplicate(true), _build_policy_context())
		if not bool(action_result.get("ok", false)):
			var policy_error := str(action_result.get("error", "Battle sandbox policy failed to select action"))
			_fail_runtime(policy_error)
			return _error_result(policy_error)
		var submit_result := _submit_action_core(action_result.get("data", {}), "manual", false)
		if not bool(submit_result.get("ok", false)):
			return submit_result
		command_steps += 1
	return {"ok": true, "data": {"command_steps": command_steps}}

func _render_ui() -> void:
	view_model = build_view_model()
	if not is_inside_tree() or _status_label == null:
		return
	_sync_launch_controls()
	_status_label.text = _format_status_text(view_model)
	_error_label.text = error_message
	_error_label.visible = not error_message.is_empty()
	_battle_summary_label.text = _format_battle_summary_text()
	_config_status_label.text = _format_config_status_text()
	_set_rich_text(_p1_summary, _format_side_text(view_model, "P1"))
	_set_rich_text(_p2_summary, _format_side_text(view_model, "P2"))
	_set_rich_text(_event_log_text, "\n".join(view_model.get("recent_event_lines", [])))
	_pending_label.text = _format_pending_text(view_model.get("pending_commands", []))
	_action_header_label.text = _format_action_header(view_model)
	_render_action_buttons(view_model)

func _render_action_buttons(current_view_model: Dictionary) -> void:
	_clear_container_children(_primary_buttons)
	_clear_container_children(_switch_buttons)
	_clear_container_children(_utility_buttons)
	_switch_label.visible = false
	if _startup_failed:
		return
	if is_demo_mode:
		_add_info_button(_primary_buttons, "Demo 回放模式：%s" % demo_profile)
		return
	if _has_battle_result():
		_add_info_button(_primary_buttons, "对局已结束，可按当前配置重开")
		return
	var side_id := str(current_view_model.get("current_side_to_select", "")).strip_edges()
	if side_id.is_empty():
		_add_info_button(_primary_buttons, "等待下一步状态同步")
		return
	if _is_policy_side(side_id):
		_add_info_button(_primary_buttons, "%s 当前由 policy 控制" % side_id)
		return
	var legal_actions: Dictionary = current_view_model.get("legal_actions_by_side", {}).get(side_id, {})
	if legal_actions.is_empty():
		_add_info_button(_primary_buttons, "当前边缺少合法动作")
		return
	for skill_id in legal_actions.get("legal_skill_ids", []):
		_add_action_button(_primary_buttons, "技能: %s" % str(skill_id), {
			"command_type": CommandTypesScript.SKILL,
			"skill_id": str(skill_id),
		})
	for ultimate_id in legal_actions.get("legal_ultimate_ids", []):
		_add_action_button(_primary_buttons, "奥义: %s" % str(ultimate_id), {
			"command_type": CommandTypesScript.ULTIMATE,
			"skill_id": str(ultimate_id),
		})
	var forced_command_type := str(legal_actions.get("forced_command_type", "")).strip_edges()
	if not forced_command_type.is_empty():
		_add_action_button(_primary_buttons, "强制: %s" % forced_command_type, {
			"command_type": forced_command_type,
		})
	if bool(legal_actions.get("wait_allowed", false)):
		_add_action_button(_utility_buttons, "等待", {
			"command_type": CommandTypesScript.WAIT,
		})
	_add_action_button(_utility_buttons, "投降", {
		"command_type": CommandTypesScript.SURRENDER,
	})
	var switch_targets: Array = legal_actions.get("legal_switch_target_public_ids", [])
	if not switch_targets.is_empty():
		_switch_label.visible = true
		for target_public_id in switch_targets:
			_add_action_button(_switch_buttons, "换人: %s" % str(target_public_id), {
				"command_type": CommandTypesScript.SWITCH,
				"target_public_id": str(target_public_id),
			})
	if _primary_buttons.get_child_count() == 0 and _switch_buttons.get_child_count() == 0 and _utility_buttons.get_child_count() == 0:
		_add_info_button(_primary_buttons, "当前边没有可渲染动作")

func _on_restart_pressed() -> void:
	if is_demo_mode:
		restart_session_with_config(launch_config)
		return
	restart_session_with_config(_build_launch_config_from_controls())

func _format_status_text(current_view_model: Dictionary) -> String:
	var mode_text := "demo=%s" % demo_profile if is_demo_mode else "manual hotseat"
	var field_id := str(current_view_model.get("field_id", "")).strip_edges()
	var current_side := str(current_view_model.get("current_side_to_select", "")).strip_edges()
	var result_text := ""
	if not battle_summary.is_empty():
		result_text = " | result=%s/%s" % [
			str(battle_summary.get("result_type", "")),
			str(battle_summary.get("reason", "")),
		]
	return "mode=%s | turn=%d | phase=%s | field=%s | current=%s%s" % [
		mode_text,
		int(current_view_model.get("turn_index", 0)),
		str(current_view_model.get("phase", "")),
		field_id if not field_id.is_empty() else "-",
		current_side if not current_side.is_empty() else "-",
		result_text,
	]

func _format_config_status_text() -> String:
	if is_demo_mode:
		return "当前配置：demo=%s（CLI 调试入口，启动控件已禁用）" % demo_profile
	return "当前配置：%s" % _launch_config_helper.build_config_summary(launch_config)

func _format_battle_summary_text() -> String:
	if battle_summary.is_empty():
		return "对局摘要: -"
	return "对局摘要: winner=%s | reason=%s | result=%s | turn=%d | events=%d" % [
		str(battle_summary.get("winner_side_id", "-")),
		str(battle_summary.get("reason", "")),
		str(battle_summary.get("result_type", "")),
		int(battle_summary.get("turn_index", 0)),
		int(battle_summary.get("event_log_cursor", 0)),
	]

func _format_side_text(current_view_model: Dictionary, side_id: String) -> String:
	var side_model := _find_side_model(current_view_model.get("sides", []), side_id)
	if side_model.is_empty():
		return "%s\nmissing side snapshot" % side_id
	var lines := [
		"%s (%s)" % [side_id, _control_mode_for_side(side_id)],
		_format_unit_block("Active", side_model.get("active", {})),
		_format_unit_list("Bench", side_model.get("bench", [])),
		_format_unit_list("Team", side_model.get("team_units", [])),
	]
	return "\n".join(lines)

func _format_unit_block(label: String, unit_model: Dictionary) -> String:
	if unit_model.is_empty():
		return "%s: -" % label
	var effect_text := _format_effects(unit_model.get("effects", []))
	return "%s: %s [%s]\nHP %d/%d | MP %d/%d | UP %d/%d req=%d\nType %s | Leave %s/%s\nEffects %s" % [
		label,
		str(unit_model.get("display_name", "")),
		str(unit_model.get("public_id", "")),
		int(unit_model.get("current_hp", 0)),
		int(unit_model.get("max_hp", 0)),
		int(unit_model.get("current_mp", 0)),
		int(unit_model.get("max_mp", 0)),
		int(unit_model.get("ultimate_points", 0)),
		int(unit_model.get("ultimate_points_cap", 0)),
		int(unit_model.get("ultimate_points_required", 0)),
		",".join(unit_model.get("combat_type_ids", [])),
		str(unit_model.get("leave_state", "-")),
		str(unit_model.get("leave_reason", "-")),
		effect_text,
	]

func _format_unit_list(label: String, units: Array) -> String:
	if units.is_empty():
		return "%s: -" % label
	var lines: Array = ["%s:" % label]
	for unit_model in units:
		if not (unit_model is Dictionary):
			continue
		lines.append("- %s [%s] HP %d/%d MP %d/%d UP %d/%d" % [
			str(unit_model.get("display_name", "")),
			str(unit_model.get("public_id", "")),
			int(unit_model.get("current_hp", 0)),
			int(unit_model.get("max_hp", 0)),
			int(unit_model.get("current_mp", 0)),
			int(unit_model.get("max_mp", 0)),
			int(unit_model.get("ultimate_points", 0)),
			int(unit_model.get("ultimate_points_cap", 0)),
		])
	return "\n".join(lines)

func _format_effects(effects: Array) -> String:
	if effects.is_empty():
		return "-"
	var entries: Array = []
	for effect_model in effects:
		if not (effect_model is Dictionary):
			continue
		entries.append("%s(%d)" % [
			str(effect_model.get("effect_definition_id", "")),
			int(effect_model.get("remaining", 0)),
		])
	return ", ".join(entries) if not entries.is_empty() else "-"

func _format_pending_text(pending_summaries: Array) -> String:
	if pending_summaries.is_empty():
		return "待提交指令: -"
	var entries: Array = []
	for pending_summary in pending_summaries:
		if not (pending_summary is Dictionary):
			continue
		var entry := "%s:%s" % [
			str(pending_summary.get("side_id", "")),
			str(pending_summary.get("command_type", "")),
		]
		var skill_id := str(pending_summary.get("skill_id", "")).strip_edges()
		var target_public_id := str(pending_summary.get("target_public_id", "")).strip_edges()
		if not skill_id.is_empty():
			entry += " skill=%s" % skill_id
		if not target_public_id.is_empty():
			entry += " target=%s" % target_public_id
		entries.append(entry)
	return "待提交指令: %s" % " | ".join(entries)

func _format_action_header(current_view_model: Dictionary) -> String:
	if _startup_failed:
		return "场景初始化失败"
	if is_demo_mode:
		return "旧回放入口：demo=%s" % demo_profile
	if _has_battle_result():
		return "结算态"
	var side_id := str(current_view_model.get("current_side_to_select", "")).strip_edges()
	if side_id.is_empty():
		return "等待下一步"
	var legal_actions: Dictionary = current_view_model.get("legal_actions_by_side", {}).get(side_id, {})
	var actor_public_id := str(legal_actions.get("actor_public_id", "")).strip_edges()
	return "当前待选边: %s | actor=%s | control=%s" % [
		side_id,
		actor_public_id if not actor_public_id.is_empty() else "-",
		_control_mode_for_side(side_id),
	]

func _append_event_lines(event_snapshots: Array) -> void:
	for event_snapshot in event_snapshots:
		recent_event_lines.append(_format_event_line(event_snapshot))
	while recent_event_lines.size() > MAX_EVENT_LINES:
		recent_event_lines.pop_front()

func _format_event_line(event_snapshot) -> String:
	if event_snapshot is Dictionary or typeof(event_snapshot) == TYPE_OBJECT:
		var event_type := str(_read_property(event_snapshot, "event_type", "")).strip_edges()
		var actor_public_id := str(_read_property(event_snapshot, "actor_public_id", "")).strip_edges()
		var target_public_id := str(_read_property(event_snapshot, "target_public_id", "")).strip_edges()
		var skill_id := str(_read_property(event_snapshot, "skill_id", "")).strip_edges()
		var command_type := str(_read_property(event_snapshot, "command_type", "")).strip_edges()
		var payload_summary := str(_read_property(event_snapshot, "payload_summary", "")).strip_edges()
		if not payload_summary.is_empty():
			return "• %s" % payload_summary
		var parts: Array = []
		if not event_type.is_empty():
			parts.append(event_type)
		if not command_type.is_empty():
			parts.append("cmd=%s" % command_type)
		if not actor_public_id.is_empty():
			parts.append("actor=%s" % actor_public_id)
		if not target_public_id.is_empty():
			parts.append("target=%s" % target_public_id)
		if not skill_id.is_empty():
			parts.append("skill=%s" % skill_id)
		if not parts.is_empty():
			return "• %s" % " | ".join(parts)
		return "• %s" % JSON.stringify(event_snapshot)
	return "• %s" % str(event_snapshot)

func _find_side_model(side_models: Array, side_id: String) -> Dictionary:
	for side_model in side_models:
		if side_model is Dictionary and str(side_model.get("side_id", "")) == side_id:
			return side_model
	return {}

func _build_view_context() -> Dictionary:
	return {
		"current_side_to_select": current_side_to_select,
		"pending_commands": pending_commands,
		"legal_actions_by_side": legal_actions_by_side,
		"recent_event_lines": recent_event_lines,
		"error_message": error_message,
		"launch_config": launch_config,
		"side_control_modes": side_control_modes,
		"available_matchups": available_matchups,
		"battle_summary": battle_summary,
	}

func _build_policy_context() -> Dictionary:
	return {
		"launch_config": launch_config.duplicate(true),
		"side_control_modes": side_control_modes.duplicate(true),
		"current_side_to_select": current_side_to_select,
		"event_log_cursor": event_log_cursor,
		"battle_summary": battle_summary.duplicate(true),
	}

func _update_battle_summary() -> void:
	battle_summary.clear()
	var battle_result = public_snapshot.get("battle_result", null)
	if not (battle_result is Dictionary) or not bool(battle_result.get("finished", false)):
		return
	battle_summary = {
		"winner_side_id": str(battle_result.get("winner_side_id", "")).strip_edges(),
		"reason": str(battle_result.get("reason", "")).strip_edges(),
		"result_type": str(battle_result.get("result_type", "")).strip_edges(),
		"turn_index": int(public_snapshot.get("turn_index", 0)),
		"event_log_cursor": event_log_cursor,
	}

func _configure_static_controls() -> void:
	_configure_mode_select(_p1_mode_select)
	_configure_mode_select(_p2_mode_select)
	_battle_seed_input.placeholder_text = str(BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)

func _configure_mode_select(option_button: OptionButton) -> void:
	option_button.clear()
	_add_option_item(option_button, BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)
	_add_option_item(option_button, BattleSandboxLaunchConfigScript.CONTROL_MODE_POLICY)

func _sync_launch_controls() -> void:
	_populate_matchup_select()
	_select_option_by_value(_p1_mode_select, _control_mode_for_side("P1"))
	_select_option_by_value(_p2_mode_select, _control_mode_for_side("P2"))
	_battle_seed_input.text = str(int(launch_config.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)))
	var controls_disabled := is_demo_mode or _launch_config_helper.visible_matchup_descriptors(available_matchups).is_empty()
	_matchup_select.disabled = controls_disabled
	_battle_seed_input.editable = not controls_disabled
	_p1_mode_select.disabled = controls_disabled
	_p2_mode_select.disabled = controls_disabled
	_restart_button.disabled = _startup_failed or (controls_disabled and not is_demo_mode)

func _populate_matchup_select() -> void:
	var visible_matchups := _launch_config_helper.visible_matchup_descriptors(available_matchups)
	_matchup_select.clear()
	for descriptor in visible_matchups:
		if not (descriptor is Dictionary):
			continue
		var matchup_id := str(descriptor.get("matchup_id", "")).strip_edges()
		if matchup_id.is_empty():
			continue
		_add_option_item(_matchup_select, matchup_id)
	if _matchup_select.item_count == 0:
		_add_option_item(_matchup_select, "no_available_matchups")
		_matchup_select.disabled = true
	else:
		_matchup_select.disabled = false
	_select_option_by_value(_matchup_select, str(launch_config.get("matchup_id", "")))

func _build_launch_config_from_controls() -> Dictionary:
	var next_config := launch_config.duplicate(true)
	next_config["mode"] = BattleSandboxLaunchConfigScript.MODE_MANUAL_MATCHUP
	next_config["demo_profile_id"] = ""
	next_config["matchup_id"] = _selected_option_value(_matchup_select)
	next_config["battle_seed"] = int(_battle_seed_input.text.to_int())
	next_config["p1_control_mode"] = _selected_option_value(_p1_mode_select)
	next_config["p2_control_mode"] = _selected_option_value(_p2_mode_select)
	return _launch_config_helper.normalize_config(next_config, available_matchups)

func _selected_option_value(option_button: OptionButton) -> String:
	if option_button == null or option_button.item_count == 0 or option_button.selected < 0:
		return ""
	return str(option_button.get_item_text(option_button.selected)).strip_edges()

func _select_option_by_value(option_button: OptionButton, value: String) -> void:
	if option_button == null:
		return
	for item_index in range(option_button.item_count):
		if str(option_button.get_item_text(item_index)).strip_edges() == value:
			option_button.select(item_index)
			return
	if option_button.item_count > 0:
		option_button.select(0)

func _add_option_item(option_button: OptionButton, text: String) -> void:
	option_button.add_item(text)

func _control_mode_for_side(side_id: String) -> String:
	return str(side_control_modes.get(side_id, BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)).strip_edges()

func _is_policy_side(side_id: String) -> bool:
	return _launch_config_helper.is_policy_control_mode(_control_mode_for_side(side_id))

func _unwrap_sample_factory_result(result: Dictionary, label: String):
	if bool(result.get("ok", false)):
		return result.get("data", null)
	error_message = "Battle sandbox failed to build %s: %s" % [
		label,
		str(result.get("error_message", "unknown error")),
	]
	return null

func _unwrap_ok(envelope: Dictionary, label: String) -> Dictionary:
	if envelope == null:
		return _error_result("%s returned null envelope" % label)
	var required_keys := ["ok", "data", "error_code", "error_message"]
	for key in required_keys:
		if not envelope.has(key):
			return _error_result("%s missing envelope key: %s" % [label, key])
	if bool(envelope.get("ok", false)):
		if envelope.get("error_code", null) != null or envelope.get("error_message", null) != null:
			return _error_result("%s success envelope should not expose error payload" % label)
		return {"ok": true, "data": envelope.get("data", null)}
	return _error_result("%s failed: %s (%s)" % [
		label,
		str(envelope.get("error_message", "")),
		str(envelope.get("error_code", "")),
	])

func _has_battle_result() -> bool:
	var battle_result = public_snapshot.get("battle_result", null)
	return battle_result is Dictionary and bool(battle_result.get("finished", false))

func _reset_state() -> void:
	session_id = ""
	battle_setup = null
	public_snapshot = {}
	event_log_cursor = 0
	legal_actions_by_side.clear()
	pending_commands.clear()
	current_side_to_select = ""
	recent_event_lines.clear()
	last_event_delta.clear()
	error_message = ""
	view_model = {}
	launch_config = _launch_config_helper.default_config()
	side_control_modes = _launch_config_helper.side_control_modes(launch_config)
	battle_summary.clear()
	available_matchups.clear()
	demo_profile = ""
	is_demo_mode = false

func _close_session_if_needed() -> void:
	if manager == null or session_id.is_empty():
		return
	manager.close_session(session_id)
	session_id = ""

func _dispose_manager() -> void:
	if manager != null and manager.has_method("dispose"):
		manager.dispose()
	manager = null
	composer = null
	sample_factory = null

func _fail_runtime(message: String) -> void:
	if message.is_empty():
		return
	error_message = message
	_startup_failed = true
	printerr("BATTLE_SANDBOX_FAILED: %s" % message)
	_render_ui()

func _clear_container_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _add_action_button(container: Node, text: String, payload: Dictionary) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 0)
	button.pressed.connect(func() -> void:
		submit_action(payload)
	)
	container.add_child(button)

func _add_info_button(container: Node, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = true
	button.custom_minimum_size = Vector2(220, 0)
	container.add_child(button)

func _set_rich_text(widget: RichTextLabel, text: String) -> void:
	widget.clear()
	widget.append_text(text if not text.is_empty() else "-")

func _read_property(value, property_name: String, default_value = null):
	if value == null or property_name.is_empty():
		return default_value
	if value is Dictionary:
		return value.get(property_name, default_value)
	if typeof(value) != TYPE_OBJECT:
		return default_value
	for property_info in value.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return value.get(property_name)
	return default_value

func _error_result(message: String) -> Dictionary:
	return {"ok": false, "error": message}
