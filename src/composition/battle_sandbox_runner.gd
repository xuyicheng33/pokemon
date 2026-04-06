extends Node
class_name BattleSandboxRunner

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

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
    var demo_mode := _resolve_demo_mode()
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

func _resolve_demo_mode() -> String:
    # Lightweight mode switch:
    # - default: kashimo (showcase Kashimo loop + ultimate)
    # - demo=legacy: preserve the original sample demo replay
    for raw_arg in OS.get_cmdline_user_args():
        var arg := String(raw_arg).strip_edges()
        if arg.begins_with("demo="):
            return String(arg.split("=", true, 1)[1]).strip_edges()
    return "kashimo"

func _build_replay_input_for_demo_mode(sample_factory, demo_mode: String) -> Variant:
    if demo_mode == "legacy":
        return sample_factory.build_demo_replay_input(manager)
    return _build_kashimo_demo_replay_input(sample_factory)

func _build_kashimo_demo_replay_input(sample_factory) -> Variant:
    var battle_setup = sample_factory.build_kashimo_vs_sample_setup()
    if battle_setup == null:
        _fail_startup("Battle sandbox failed to build kashimo demo setup")
        return null
    var snapshot_paths_result: Dictionary = sample_factory.content_snapshot_paths_for_setup_result(battle_setup)
    if not bool(snapshot_paths_result.get("ok", false)):
        _fail_startup("Battle sandbox content snapshot build failed: %s" % str(snapshot_paths_result.get("error_message", "unknown error")))
        return null
    var replay_input = ReplayInputScript.new()
    replay_input.battle_seed = 9101
    replay_input.content_snapshot_paths = snapshot_paths_result.get("data", PackedStringArray())
    # NOTE: build_kashimo_vs_sample_setup is wired in SampleBattleFactory (formal delivery surface).
    replay_input.battle_setup = battle_setup

    # This is a minimal, stable demo of Kashimo's loop:
    # - Raiken: apply negative charge
    # - Charge: stack positive charge (MP income)
    # - Feedback Strike: consume charges for big hit
    # - Ultimate: Phantom Beast Amber (persistent stages + self-bleed + ultimate lock)
    # Intentionally provide only P1 commands.
    # Missing P2 command for a turn is resolved as an auto-wait for the current active unit,
    # avoiding fragile public_id assumptions if P2 gets replaced mid-demo.
    replay_input.command_stream = [
        _cmd({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "kashimo_raiken",
        }),
        _cmd({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "kashimo_charge",
        }),
        _cmd({
            "turn_index": 3,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "kashimo_feedback_strike",
        }),
        _cmd({
            "turn_index": 4,
            "command_type": CommandTypesScript.ULTIMATE,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "kashimo_phantom_beast_amber",
        }),
        _cmd({
            "turn_index": 5,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
        }),
    ]
    if _startup_failed:
        return null
    return replay_input

func _cmd(payload: Dictionary) -> Variant:
    var envelope: Dictionary = manager.build_command(payload)
    if not bool(envelope.get("ok", false)):
        _fail_startup("Battle sandbox command build failed: %s" % str(envelope.get("error_message", "unknown error")))
        return null
    return envelope.get("data", null)

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
