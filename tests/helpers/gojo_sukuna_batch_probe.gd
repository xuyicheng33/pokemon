extends SceneTree

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const BattleSetupScript := preload("res://src/battle_core/contracts/battle_setup.gd")
const SideSetupScript := preload("res://src/battle_core/contracts/side_setup.gd")
const BattleAIAdapterScript := preload("res://src/adapters/battle_ai_adapter.gd")
const GojoSukunaProbeSupportScript := preload("res://tests/support/gojo_sukuna_probe_support.gd")

var _support := GojoSukunaProbeSupportScript.new()

func _init() -> void:
    var battles := _resolve_battles()
    var run_naive := _env_enabled("RUN_NAIVE", true)
    var run_heuristic := _env_enabled("RUN_HEURISTIC", true)
    var symmetric_only := _env_enabled("SYMMETRIC_ONLY", true)
    for loadout_mode in _resolve_loadout_modes():
        if run_naive:
            _run_experiment("naive", battles, symmetric_only, loadout_mode)
        if run_heuristic:
            _run_experiment("heuristic", battles, symmetric_only, loadout_mode)
    quit()

func _resolve_battles() -> int:
    var raw := str(OS.get_environment("BATTLES")).strip_edges()
    if raw.is_empty():
        return 200
    return max(1, int(raw))

func _env_enabled(name: String, default_value: bool) -> bool:
    var raw := str(OS.get_environment(name)).strip_edges().to_lower()
    if raw.is_empty():
        return default_value
    return raw != "0" and raw != "false" and raw != "no"

func _resolve_loadout_modes() -> Array[String]:
    var raw := str(OS.get_environment("LOADOUT_MODES")).strip_edges().to_lower()
    if raw.is_empty():
        return ["default", "reverse"]
    var modes: Array[String] = []
    for part in raw.split(","):
        var normalized := str(part).strip_edges().to_lower()
        if normalized != "default" and normalized != "reverse":
            continue
        if not modes.has(normalized):
            modes.append(normalized)
    return modes if not modes.is_empty() else ["default", "reverse"]

func _run_experiment(policy: String, battles: int, symmetric_only: bool, loadout_mode: String) -> void:
    var composer = BattleCoreComposerScript.new()
    var manager = composer.compose_manager()
    var ai_adapter = BattleAIAdapterScript.new()
    var sample_factory = SampleBattleFactoryScript.new()
    var content_paths = sample_factory.content_snapshot_paths()
    var totals := _support.build_totals()
    var completed_matches := 0

    for i in range(battles):
        var gojo_on_p1 := i % 2 == 0
        var battle_setup = _build_setup(gojo_on_p1, symmetric_only, loadout_mode)
        var battle_seed := 1000 + i
        var init_result: Dictionary = manager.create_session({
            "battle_seed": battle_seed,
            "content_snapshot_paths": content_paths,
            "battle_setup": battle_setup,
        })
        var session_id := str(init_result.get("session_id", ""))
        var snapshot: Dictionary = init_result.get("public_snapshot", {})
        var match_stats := _support.build_match_stats()
        var aborted_match := false
        var safety := 0

        while not bool(snapshot.get("battle_result", {}).get("finished", false)):
            safety += 1
            if safety > 80:
                push_error("probe exceeded 80 turns on seed %d" % battle_seed)
                aborted_match = true
                break

            var log_snapshot: Dictionary = manager.get_event_log_snapshot(session_id)
            var log_size_before: int = int(log_snapshot.get("total_size", 0))
            var commands: Array = []

            for side_snapshot in snapshot.get("sides", []):
                var side_id := str(side_snapshot.get("side_id", ""))
                var legal_action_set = manager.get_legal_actions(session_id, side_id)
                _support.tally_ultimate_legal_window(snapshot, side_id, legal_action_set, match_stats)
                if not str(legal_action_set.forced_command_type).is_empty():
                    continue
                var choice := _choose_action(ai_adapter, policy, snapshot, side_id, legal_action_set)
                if choice.is_empty():
                    continue
                _support.tally_choice(snapshot, side_id, choice, match_stats)
                var payload := {
                    "turn_index": int(snapshot.get("turn_index", 0)),
                    "command_type": str(choice.get("command_type", "")),
                    "command_source": "ai",
                    "side_id": side_id,
                    "actor_public_id": str(legal_action_set.actor_public_id),
                }
                if choice.has("skill_id"):
                    payload["skill_id"] = choice["skill_id"]
                if choice.has("target_public_id"):
                    payload["target_public_id"] = choice["target_public_id"]
                commands.append(manager.build_command(payload))

            var turn_result: Dictionary = manager.run_turn(session_id, commands)
            var turn_log_delta: Dictionary = manager.get_event_log_snapshot(session_id, log_size_before)
            _support.tally_resolved_turn(turn_log_delta.get("events", []), match_stats)
            snapshot = turn_result.get("public_snapshot", {})

        if aborted_match:
            manager.close_session(session_id)
            totals.aborted_matches += 1
            continue

        manager.close_session(session_id)
        completed_matches += 1
        _support.accumulate_totals(totals, match_stats, snapshot, gojo_on_p1)

    print(_support.format_summary(policy, symmetric_only, loadout_mode, totals, completed_matches))
    manager.dispose()

func _build_setup(gojo_on_p1: bool, symmetric_only: bool, loadout_mode: String):
    var battle_setup = BattleSetupScript.new()
    battle_setup.format_id = "prototype_full_open"
    var p1 = SideSetupScript.new()
    p1.side_id = "P1"
    p1.starting_index = 0
    p1.regular_skill_loadout_overrides = {}
    var p2 = SideSetupScript.new()
    p2.side_id = "P2"
    p2.starting_index = 0
    p2.regular_skill_loadout_overrides = {}

    if symmetric_only:
        p1.unit_definition_ids = PackedStringArray([
            "gojo_satoru" if gojo_on_p1 else "sukuna",
            "sample_mossaur",
            "sample_tidekit",
        ])
        p2.unit_definition_ids = PackedStringArray([
            "sukuna" if gojo_on_p1 else "gojo_satoru",
            "sample_mossaur",
            "sample_tidekit",
        ])
    else:
        p1.unit_definition_ids = PackedStringArray([
            "gojo_satoru" if gojo_on_p1 else "sukuna",
            "sample_mossaur",
            "sample_pyron",
        ])
        p2.unit_definition_ids = PackedStringArray([
            "sukuna" if gojo_on_p1 else "gojo_satoru",
            "sample_tidekit",
            "sample_mossaur",
        ])

    _support.apply_loadout_mode(p1, loadout_mode)
    _support.apply_loadout_mode(p2, loadout_mode)
    battle_setup.sides = [p1, p2]
    return battle_setup

func _choose_action(ai_adapter, policy: String, snapshot: Dictionary, side_id: String, legal_action_set) -> Dictionary:
    return ai_adapter.choose_command(legal_action_set, snapshot, side_id, policy)
