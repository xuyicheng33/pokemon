extends Node
class_name BattleSandboxRunner

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")

var composer
var manager
var _startup_failed: bool = false

func _ready() -> void:
    _startup_failed = false
    composer = BattleCoreComposerScript.new()
    if composer == null:
        _fail_startup("Battle sandbox failed to construct composer")
        return
    manager = composer.compose_manager()
    if manager == null:
        var composer_error: Dictionary = composer.error_state()
        _fail_startup(
            "Battle sandbox failed to compose manager: %s" % str(composer_error.get("message", "unknown composition error"))
        )
        return
    var sample_factory: Variant = SampleBattleFactoryScript.new()
    if sample_factory == null:
        _fail_startup("Battle sandbox failed to construct sample battle factory")
        return
    var demo_mode_result := _resolve_demo_mode_result(sample_factory)
    if not bool(demo_mode_result.get("ok", false)):
        _fail_startup("Battle sandbox failed to resolve demo profile: %s" % str(demo_mode_result.get("error_message", "unknown error")))
        return
    var demo_mode := String(demo_mode_result.get("data", "")).strip_edges()
    if demo_mode.is_empty():
        _fail_startup("Battle sandbox resolved empty demo profile")
        return
    var replay_input = _build_replay_input_for_demo_mode(sample_factory, demo_mode)
    if _startup_failed:
        return
    var replay_input_error := _validate_replay_input(replay_input)
    if not replay_input_error.is_empty():
        _fail_startup(replay_input_error)
        return
    var replay_envelope: Dictionary = manager.run_replay(replay_input)
    if not bool(replay_envelope.get("ok", false)):
        _fail_startup("Battle sandbox replay failed: %s" % str(replay_envelope.get("error_message", "unknown error")))
        return

func _resolve_demo_mode_result(sample_factory) -> Dictionary:
    for raw_arg in OS.get_cmdline_user_args():
        var arg := String(raw_arg).strip_edges()
        if arg.begins_with("demo="):
            return {
                "ok": true,
                "data": String(arg.split("=", true, 1)[1]).strip_edges(),
                "error_message": null,
            }
    if sample_factory == null or not sample_factory.has_method("default_demo_profile_id_result"):
        return {
            "ok": false,
            "data": null,
            "error_message": "sample factory missing default_demo_profile_id_result",
        }
    var default_profile_result: Dictionary = sample_factory.default_demo_profile_id_result()
    if not bool(default_profile_result.get("ok", false)):
        return {
            "ok": false,
            "data": null,
            "error_message": default_profile_result.get("error_message", "unknown error"),
        }
    return {
        "ok": true,
        "data": String(default_profile_result.get("data", "")).strip_edges(),
        "error_message": null,
    }

func _build_replay_input_for_demo_mode(sample_factory, demo_mode: String) -> Variant:
    var replay_result: Dictionary = sample_factory.build_demo_replay_input_for_profile_result(manager, demo_mode)
    return _unwrap_sample_factory_result(replay_result, "%s demo replay input" % demo_mode)

func _unwrap_sample_factory_result(result: Dictionary, label: String):
    if bool(result.get("ok", false)):
        return result.get("data", null)
    _fail_startup(
        "Battle sandbox failed to build %s: %s" % [label, str(result.get("error_message", "unknown error"))]
    )
    return null

func _validate_replay_input(replay_input) -> String:
    if replay_input == null:
        return "Battle sandbox failed to build replay input"
    if replay_input.battle_setup == null:
        return "Battle sandbox replay input missing battle_setup"
    if replay_input.content_snapshot_paths.is_empty():
        return "Battle sandbox replay input missing content_snapshot_paths"
    if replay_input.command_stream.is_empty():
        return "Battle sandbox replay input missing command_stream"
    for command_index in range(replay_input.command_stream.size()):
        if replay_input.command_stream[command_index] == null:
            return "Battle sandbox replay input contains null command at index %d" % command_index
    return ""

func _fail_startup(message: String) -> void:
    if _startup_failed:
        return
    _startup_failed = true
    printerr("BATTLE_SANDBOX_FAILED: %s" % message)
    if get_tree() != null:
        get_tree().quit(1)
