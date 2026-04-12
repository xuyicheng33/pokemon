extends Control
class_name BattleSandboxController

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")
const BattleUIViewModelBuilderScript := preload("res://src/adapters/battle_ui_view_model_builder.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

const FIXED_MATCHUP_ID := "gojo_vs_sample"
const SIDE_ORDER := ["P1", "P2"]
const MAX_EVENT_LINES := 24

@onready var _status_label: Label = $RootMargin/MainColumn/HeaderPanel/HeaderContent/StatusLabel
@onready var _error_label: Label = $RootMargin/MainColumn/HeaderPanel/HeaderContent/ErrorLabel
@onready var _p1_summary: RichTextLabel = $RootMargin/MainColumn/BodyRow/P1Panel/P1Content/P1Summary
@onready var _event_log_text: RichTextLabel = $RootMargin/MainColumn/BodyRow/EventPanel/EventContent/EventLogText
@onready var _p2_summary: RichTextLabel = $RootMargin/MainColumn/BodyRow/P2Panel/P2Content/P2Summary
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

var demo_profile: String = ""
var is_demo_mode: bool = false
var manual_battle_seed: int = 9101

var _selection_adapter = PlayerSelectionAdapterScript.new()
var _view_model_builder = BattleUIViewModelBuilderScript.new()
var _startup_failed: bool = false

func _ready() -> void:
    _restart_button.pressed.connect(_on_restart_pressed)
    bootstrap_from_environment()

func _exit_tree() -> void:
    _close_session_if_needed()
    _dispose_manager()

func build_view_model() -> Dictionary:
    return _view_model_builder.build_view_model(public_snapshot, _build_view_context())

func bootstrap_from_environment() -> Dictionary:
    _startup_failed = false
    demo_profile = _resolve_demo_profile()
    if not demo_profile.is_empty():
        is_demo_mode = true
        return _bootstrap_scene()
    is_demo_mode = false
    return bootstrap_manual_mode(manual_battle_seed)

func bootstrap_manual_mode(battle_seed: int = 9101) -> Dictionary:
    manual_battle_seed = battle_seed
    demo_profile = ""
    is_demo_mode = false
    return _bootstrap_scene()

func restart_manual_session(battle_seed: int = -1) -> Dictionary:
    if battle_seed > 0:
        manual_battle_seed = battle_seed
    demo_profile = ""
    is_demo_mode = false
    return _bootstrap_scene()

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
    var manual_payload: Dictionary = selected_action.duplicate(true)
    manual_payload["side_id"] = side_id
    manual_payload["actor_public_id"] = actor_public_id
    manual_payload["turn_index"] = int(public_snapshot.get("turn_index", 1))
    manual_payload["command_source"] = "manual"
    var command_payload: Dictionary = _selection_adapter.build_player_payload(manual_payload)
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
        _render_ui()
        return {"ok": true, "data": {"side_id": side_id, "pending_commands": pending_commands.size()}}
    var run_turn_unwrap := _run_pending_turn()
    if not bool(run_turn_unwrap.get("ok", false)):
        return run_turn_unwrap
    return {"ok": true, "data": run_turn_unwrap.get("data", {})}

func _bootstrap_scene() -> Dictionary:
    _startup_failed = false
    error_message = ""
    _close_session_if_needed()
    _dispose_manager()
    _reset_state()
    var compose_error := _compose_dependencies()
    if not compose_error.is_empty():
        _fail_runtime(compose_error)
        return _error_result(compose_error)
    if is_demo_mode:
        var replay_error := _run_demo_replay(demo_profile)
        if not replay_error.is_empty():
            _fail_runtime(replay_error)
            return _error_result(replay_error)
        _render_ui()
        return {"ok": true, "data": get_state_snapshot()}
    var manual_error := _create_fixed_session()
    if not manual_error.is_empty():
        _fail_runtime(manual_error)
        return _error_result(manual_error)
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
    last_event_delta = event_log.duplicate()
    _append_event_lines(event_log)
    event_log_cursor = event_log.size()
    current_side_to_select = ""
    pending_commands.clear()
    legal_actions_by_side.clear()
    return ""

func _create_fixed_session() -> String:
    var setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(FIXED_MATCHUP_ID)
    if not bool(setup_result.get("ok", false)):
        return "Battle sandbox failed to build matchup %s: %s" % [
            FIXED_MATCHUP_ID,
            str(setup_result.get("error_message", "unknown error")),
        ]
    battle_setup = setup_result.get("data", {})
    if battle_setup == null:
        return "Battle sandbox received empty battle_setup for %s" % FIXED_MATCHUP_ID
    var snapshot_paths_result: Dictionary = sample_factory.content_snapshot_paths_for_setup_result(battle_setup)
    if not bool(snapshot_paths_result.get("ok", false)):
        return "Battle sandbox failed to resolve setup snapshot paths: %s" % str(snapshot_paths_result.get("error_message", "unknown error"))
    var create_unwrap := _unwrap_ok(manager.create_session({
        "battle_seed": manual_battle_seed,
        "content_snapshot_paths": snapshot_paths_result.get("data", PackedStringArray()),
        "battle_setup": battle_setup,
    }), "create_session(%s)" % FIXED_MATCHUP_ID)
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
    return ""

func _refresh_legal_actions_for_side(side_id: String) -> Dictionary:
    if side_id.is_empty():
        return {"ok": true, "data": null}
    var legal_actions_unwrap := _unwrap_ok(manager.get_legal_actions(session_id, side_id), "get_legal_actions(%s)" % side_id)
    if not bool(legal_actions_unwrap.get("ok", false)):
        return legal_actions_unwrap
    legal_actions_by_side[side_id] = legal_actions_unwrap.get("data", null)
    return legal_actions_unwrap

func _run_pending_turn() -> Dictionary:
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
    _render_ui()
    return {
        "ok": true,
        "data": {
            "event_log_cursor": event_log_cursor,
            "battle_finished": _has_battle_result(),
            "event_delta": last_event_delta.duplicate(true),
            "public_snapshot": public_snapshot.duplicate(true),
            "current_side_to_select": current_side_to_select,
        }
    }

func _render_ui() -> void:
    view_model = build_view_model()
    if not is_inside_tree() or _status_label == null:
        return
    _status_label.text = _format_status_text(view_model)
    _error_label.text = error_message
    _error_label.visible = not error_message.is_empty()
    _set_rich_text(_p1_summary, _format_side_text(view_model, "P1"))
    _set_rich_text(_p2_summary, _format_side_text(view_model, "P2"))
    _set_rich_text(_event_log_text, "\n".join(view_model.get("recent_event_lines", [])))
    _pending_label.text = _format_pending_text(view_model.get("pending_commands", []))
    _action_header_label.text = _format_action_header(view_model)
    _render_action_buttons(view_model)

func _render_action_buttons(view_model: Dictionary) -> void:
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
        _add_info_button(_primary_buttons, "对局已结束，可点击下方重开")
        return
    var side_id := str(view_model.get("current_side_to_select", "")).strip_edges()
    if side_id.is_empty():
        _add_info_button(_primary_buttons, "等待下一步状态同步")
        return
    var legal_actions: Dictionary = view_model.get("legal_actions_by_side", {}).get(side_id, {})
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
    _bootstrap_scene()

func _format_status_text(view_model: Dictionary) -> String:
    var mode_text := "demo=%s" % demo_profile if is_demo_mode else "manual hotseat"
    var field_id := str(view_model.get("field_id", "")).strip_edges()
    var current_side := str(view_model.get("current_side_to_select", "")).strip_edges()
    var result_text := ""
    var battle_result = view_model.get("battle_result", null)
    if battle_result is Dictionary and bool(battle_result.get("finished", false)):
        result_text = " | result=%s/%s" % [
            str(battle_result.get("result_type", "")),
            str(battle_result.get("reason", "")),
        ]
    return "mode=%s | turn=%d | phase=%s | field=%s | current=%s%s" % [
        mode_text,
        int(view_model.get("turn_index", 0)),
        str(view_model.get("phase", "")),
        field_id if not field_id.is_empty() else "-",
        current_side if not current_side.is_empty() else "-",
        result_text,
    ]

func _format_side_text(view_model: Dictionary, side_id: String) -> String:
    var side_model := _find_side_model(view_model.get("sides", []), side_id)
    if side_model.is_empty():
        return "%s\nmissing side snapshot" % side_id
    var lines := [
        "%s" % side_id,
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
    var lines: Array[String] = ["%s:" % label]
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
    var entries: Array[String] = []
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
    var entries: Array[String] = []
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

func _format_action_header(view_model: Dictionary) -> String:
    if _startup_failed:
        return "场景初始化失败"
    if is_demo_mode:
        return "旧回放入口：demo=%s" % demo_profile
    if _has_battle_result():
        return "结算态"
    var side_id := str(view_model.get("current_side_to_select", "")).strip_edges()
    if side_id.is_empty():
        return "等待下一步"
    var legal_actions: Dictionary = view_model.get("legal_actions_by_side", {}).get(side_id, {})
    var actor_public_id := str(legal_actions.get("actor_public_id", "")).strip_edges()
    return "当前待选边: %s | actor=%s" % [side_id, actor_public_id if not actor_public_id.is_empty() else "-"]

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
        var parts: Array[String] = []
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
    }

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

func _resolve_demo_profile() -> String:
    for raw_arg in OS.get_cmdline_user_args():
        var arg := str(raw_arg).strip_edges()
        if arg.begins_with("demo="):
            return str(arg.split("=", true, 1)[1]).strip_edges()
    return ""

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
