extends RefCounted
class_name KashimoAmberSuite

const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _support = KashimoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("kashimo_phantom_beast_amber_persistent_stage_contract", failures, Callable(self, "_test_kashimo_phantom_beast_amber_persistent_stage_contract").bind(harness))

func _test_kashimo_phantom_beast_amber_persistent_stage_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = _support.build_battle_state(core, content_index, _support.build_kashimo_setup(sample_factory), 910)
    var kashimo = battle_state.get_side("P1").get_active_unit()
    if kashimo == null:
        return harness.fail_result("missing kashimo active unit for amber contract")
    kashimo.current_mp = kashimo.max_mp
    kashimo.ultimate_points = kashimo.ultimate_points_cap

    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_ultimate_command(core, 1, "P1", "P1-A", "kashimo_phantom_beast_amber"),
        _support.build_manual_wait_command(core, 1, "P2", _active_public_id(battle_state, "P2")),
    ])
    if int(kashimo.persistent_stat_stages.get("attack", 0)) != 2 or int(kashimo.persistent_stat_stages.get("sp_attack", 0)) != 2 or int(kashimo.persistent_stat_stages.get("speed", 0)) != 1:
        return harness.fail_result("amber should apply persistent +2/+2/+1 stat stages")
    if kashimo.current_hp != 98:
        return harness.fail_result("amber should deal 20 self damage at turn_end after cast: expected=98 actual=%d" % kashimo.current_hp)
    if not _has_effect_instance(kashimo, "kashimo_amber_bleed"):
        return harness.fail_result("amber should apply persistent bleed effect")
    if not _has_rule_mod(kashimo, "action_legality", "ultimate"):
        return harness.fail_result("amber should apply persistent ultimate lock rule_mod")
    if kashimo.ultimate_points != 0:
        return harness.fail_result("amber cast should clear ultimate points")

    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_switch_command(core, 2, "P1", "P1-A", "P1-B"),
        _support.build_manual_wait_command(core, 2, "P2", _active_public_id(battle_state, "P2")),
    ])
    if int(kashimo.persistent_stat_stages.get("attack", 0)) != 2:
        return harness.fail_result("persistent attack stage should survive switch after amber")
    if not _has_effect_instance(kashimo, "kashimo_amber_bleed") or not _has_rule_mod(kashimo, "action_legality", "ultimate"):
        return harness.fail_result("amber bleed and ultimate lock should survive switch")
    if kashimo.current_hp != 98:
        return harness.fail_result("amber self damage should not disappear statefully while benched: expected hp=98 actual=%d" % kashimo.current_hp)

    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_switch_command(core, 3, "P1", "P1-B", "P1-A"),
        _support.build_manual_wait_command(core, 3, "P2", _active_public_id(battle_state, "P2")),
    ])
    if kashimo.current_hp != 98:
        return harness.fail_result("amber self damage should stay paused on the same turn the user re-enters: expected=98 actual=%d" % kashimo.current_hp)
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_wait_command(core, 4, "P1", "P1-A"),
        _support.build_manual_wait_command(core, 4, "P2", _active_public_id(battle_state, "P2")),
    ])
    if kashimo.current_hp != 78:
        return harness.fail_result("amber self damage should resume on the next full active turn after re-entry: expected=78 actual=%d" % kashimo.current_hp)
    kashimo.ultimate_points = kashimo.ultimate_points_cap
    var legal_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
    if legal_actions.legal_ultimate_ids.has("kashimo_phantom_beast_amber"):
        return harness.fail_result("amber ultimate lock should deny second ultimate even after refilling points")

    core.service("leave_service").leave_unit(battle_state, kashimo, "faint", content_index)
    if int(kashimo.persistent_stat_stages.get("attack", 0)) != 0 or int(kashimo.persistent_stat_stages.get("sp_attack", 0)) != 0 or int(kashimo.persistent_stat_stages.get("speed", 0)) != 0:
        return harness.fail_result("persistent stat stages should clear on faint")
    if _has_effect_instance(kashimo, "kashimo_amber_bleed") or _has_rule_mod(kashimo, "action_legality", "ultimate"):
        return harness.fail_result("amber bleed and ultimate lock should clear on faint")
    return harness.pass_result()

func _has_effect_instance(unit_state, effect_id: String) -> bool:
    for effect_instance in unit_state.effect_instances:
        if String(effect_instance.def_id) == effect_id:
            return true
    return false

func _has_rule_mod(unit_state, mod_kind: String, value: String) -> bool:
    for rule_mod_instance in unit_state.rule_mod_instances:
        if String(rule_mod_instance.mod_kind) == mod_kind and String(rule_mod_instance.value) == value:
            return true
    return false

func _active_public_id(battle_state, side_id: String) -> String:
    var side = battle_state.get_side(side_id)
    if side == null:
        return ""
    var active = side.get_active_unit()
    if active == null:
        return ""
    return String(active.public_id)
