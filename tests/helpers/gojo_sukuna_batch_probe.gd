extends SceneTree

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const BattleSetupScript := preload("res://src/battle_core/contracts/battle_setup.gd")
const SideSetupScript := preload("res://src/battle_core/contracts/side_setup.gd")
const BattleAIAdapterScript := preload("res://src/adapters/battle_ai_adapter.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

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
    var totals := {
        "matches": 0,
        "aborted_matches": 0,
        "gojo_wins": 0,
        "sukuna_wins": 0,
        "draws": 0,
        "turn_sum": 0,
        "gojo_ult_chosen": 0,
        "sukuna_ult_chosen": 0,
        "gojo_ult_resolved": 0,
        "sukuna_ult_resolved": 0,
        "gojo_heal_chosen": 0,
        "sukuna_heal_chosen": 0,
        "gojo_heal_resolved": 0,
        "sukuna_heal_resolved": 0,
        "gojo_domain_successes": 0,
        "sukuna_domain_successes": 0,
        "gojo_ult_legal_windows": 0,
        "sukuna_ult_legal_windows": 0,
    }
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
        var match_stats := {
            "gojo_ult_chosen": 0,
            "sukuna_ult_chosen": 0,
            "gojo_ult_resolved": 0,
            "sukuna_ult_resolved": 0,
            "gojo_heal_chosen": 0,
            "sukuna_heal_chosen": 0,
            "gojo_heal_resolved": 0,
            "sukuna_heal_resolved": 0,
            "gojo_domain_successes": 0,
            "sukuna_domain_successes": 0,
            "gojo_ult_legal_windows": 0,
            "sukuna_ult_legal_windows": 0,
        }
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
                _tally_ultimate_legal_window(snapshot, side_id, legal_action_set, match_stats)
                if not str(legal_action_set.forced_command_type).is_empty():
                    continue
                var choice := _choose_action(ai_adapter, policy, snapshot, side_id, legal_action_set)
                if choice.is_empty():
                    continue
                _tally_choice(snapshot, side_id, choice, match_stats)
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
            _tally_resolved_turn(turn_log_delta.get("events", []), match_stats)
            snapshot = turn_result.get("public_snapshot", {})
        if aborted_match:
            manager.close_session(session_id)
            totals.aborted_matches += 1
            continue
        manager.close_session(session_id)
        totals.matches += 1
        completed_matches += 1
        totals.turn_sum += int(snapshot.get("turn_index", 0))
        totals.gojo_ult_chosen += int(match_stats.gojo_ult_chosen)
        totals.sukuna_ult_chosen += int(match_stats.sukuna_ult_chosen)
        totals.gojo_ult_resolved += int(match_stats.gojo_ult_resolved)
        totals.sukuna_ult_resolved += int(match_stats.sukuna_ult_resolved)
        totals.gojo_heal_chosen += int(match_stats.gojo_heal_chosen)
        totals.sukuna_heal_chosen += int(match_stats.sukuna_heal_chosen)
        totals.gojo_heal_resolved += int(match_stats.gojo_heal_resolved)
        totals.sukuna_heal_resolved += int(match_stats.sukuna_heal_resolved)
        totals.gojo_domain_successes += int(match_stats.gojo_domain_successes)
        totals.sukuna_domain_successes += int(match_stats.sukuna_domain_successes)
        totals.gojo_ult_legal_windows += int(match_stats.gojo_ult_legal_windows)
        totals.sukuna_ult_legal_windows += int(match_stats.sukuna_ult_legal_windows)
        var winner_side_id = snapshot.get("battle_result", {}).get("winner_side_id", null)
        if winner_side_id == null:
            totals.draws += 1
        elif (gojo_on_p1 and winner_side_id == "P1") or (not gojo_on_p1 and winner_side_id == "P2"):
            totals.gojo_wins += 1
        else:
            totals.sukuna_wins += 1
    var avg_turns := float(totals.turn_sum) / float(max(1, completed_matches))
    print("policy=%s setup=%s loadout=%s matches=%d aborted_matches=%d gojo_wins=%d sukuna_wins=%d draws=%d avg_turns=%.2f gojo_ult_chosen=%d sukuna_ult_chosen=%d gojo_ult_resolved=%d sukuna_ult_resolved=%d gojo_ult_legal_windows=%d sukuna_ult_legal_windows=%d gojo_heal_chosen=%d sukuna_heal_chosen=%d gojo_heal_resolved=%d sukuna_heal_resolved=%d gojo_domain_successes=%d sukuna_domain_successes=%d" % [
        policy,
        "symmetric" if symmetric_only else "sample_factory",
        loadout_mode,
        totals.matches,
        totals.aborted_matches,
        totals.gojo_wins,
        totals.sukuna_wins,
        totals.draws,
        avg_turns,
        totals.gojo_ult_chosen,
        totals.sukuna_ult_chosen,
        totals.gojo_ult_resolved,
        totals.sukuna_ult_resolved,
        totals.gojo_ult_legal_windows,
        totals.sukuna_ult_legal_windows,
        totals.gojo_heal_chosen,
        totals.sukuna_heal_chosen,
        totals.gojo_heal_resolved,
        totals.sukuna_heal_resolved,
        totals.gojo_domain_successes,
        totals.sukuna_domain_successes,
    ])
    manager.dispose()

func _tally_resolved_turn(event_log: Array, stats: Dictionary) -> void:
    for log_event in event_log:
        if typeof(log_event) != TYPE_DICTIONARY:
            continue
        if String(log_event.get("event_type", "")) == EventTypesScript.ACTION_CAST:
            var actor_def_id := str(log_event.get("actor_definition_id", ""))
            if actor_def_id == "gojo_satoru" and String(log_event.get("command_type", "")) == "ultimate":
                stats.gojo_ult_resolved += 1
            elif actor_def_id == "sukuna" and String(log_event.get("command_type", "")) == "ultimate":
                stats.sukuna_ult_resolved += 1
            continue
        if String(log_event.get("event_type", "")) == EventTypesScript.EFFECT_HEAL:
            var heal_target_def_id := str(log_event.get("target_definition_id", ""))
            if heal_target_def_id == "gojo_satoru":
                stats.gojo_heal_resolved += 1
            elif heal_target_def_id == "sukuna":
                stats.sukuna_heal_resolved += 1
            continue
        if String(log_event.get("event_type", "")) == EventTypesScript.EFFECT_APPLY_FIELD and typeof(log_event.get("field_change", null)) == TYPE_DICTIONARY:
            var applied_field_id := String(log_event.get("field_change", {}).get("after_field_id", ""))
            if applied_field_id == "gojo_unlimited_void_field":
                stats.gojo_domain_successes += 1
            elif applied_field_id == "sukuna_malevolent_shrine_field":
                stats.sukuna_domain_successes += 1

func _tally_ultimate_legal_window(snapshot: Dictionary, side_id: String, legal_action_set, stats: Dictionary) -> void:
    if legal_action_set == null or legal_action_set.legal_ultimate_ids.is_empty():
        return
    var actor := _find_active_unit(snapshot, side_id)
    var actor_def_id := str(actor.get("definition_id", ""))
    if actor_def_id == "gojo_satoru":
        stats.gojo_ult_legal_windows += 1
    elif actor_def_id == "sukuna":
        stats.sukuna_ult_legal_windows += 1

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
    _apply_loadout_mode(p1, loadout_mode)
    _apply_loadout_mode(p2, loadout_mode)
    battle_setup.sides = [p1, p2]
    return battle_setup

func _apply_loadout_mode(side_setup, loadout_mode: String) -> void:
    if loadout_mode != "reverse":
        return
    if side_setup.unit_definition_ids.is_empty():
        return
    var lead_unit_id := String(side_setup.unit_definition_ids[0])
    match lead_unit_id:
        "gojo_satoru":
            side_setup.regular_skill_loadout_overrides[0] = PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
        "sukuna":
            side_setup.regular_skill_loadout_overrides[0] = PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])

func _choose_action(ai_adapter, policy: String, snapshot: Dictionary, side_id: String, legal_action_set) -> Dictionary:
    return ai_adapter.choose_command(legal_action_set, snapshot, side_id, policy)

func _find_side_snapshot(snapshot: Dictionary, side_id: String) -> Dictionary:
    for side_snapshot in snapshot.get("sides", []):
        if str(side_snapshot.get("side_id", "")) == side_id:
            return side_snapshot
    return {}

func _find_active_unit(snapshot: Dictionary, side_id: String) -> Dictionary:
    var side_snapshot := _find_side_snapshot(snapshot, side_id)
    var active_public_id := str(side_snapshot.get("active_public_id", ""))
    for unit_snapshot in side_snapshot.get("team_units", []):
        if str(unit_snapshot.get("public_id", "")) == active_public_id:
            return unit_snapshot
    return {}

func _tally_choice(snapshot: Dictionary, side_id: String, choice: Dictionary, stats: Dictionary) -> void:
    var actor := _find_active_unit(snapshot, side_id)
    var actor_def_id := str(actor.get("definition_id", ""))
    var skill_id := str(choice.get("skill_id", ""))
    if actor_def_id == "gojo_satoru":
        if skill_id == "gojo_unlimited_void":
            stats.gojo_ult_chosen += 1
        elif skill_id == "gojo_reverse_ritual":
            stats.gojo_heal_chosen += 1
    elif actor_def_id == "sukuna":
        if skill_id == "sukuna_fukuma_mizushi":
            stats.sukuna_ult_chosen += 1
        elif skill_id == "sukuna_reverse_ritual":
            stats.sukuna_heal_chosen += 1
