extends RefCounted
class_name SukunaSetupRegenSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const SukunaTestSupportScript := preload("res://tests/support/sukuna_test_support.gd")

var _support = SukunaTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("sukuna_default_loadout_contract", failures, Callable(self, "_test_sukuna_default_loadout_contract").bind(harness))
    runner.run_test("sukuna_matchup_regen_runtime_path", failures, Callable(self, "_test_sukuna_matchup_regen_runtime_path").bind(harness))
    runner.run_test("sukuna_reverse_ritual_heal_path", failures, Callable(self, "_test_sukuna_reverse_ritual_heal_path").bind(harness))
func _test_sukuna_default_loadout_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var sukuna = content_index.units.get("sukuna", null)
    if sukuna == null:
        return harness.fail_result("missing sukuna unit definition")
    if sukuna.skill_ids != PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku"]):
        return harness.fail_result("sukuna default loadout must stay fixed as 解/捌/开")
    if sukuna.skill_ids.has("sukuna_reverse_ritual"):
        return harness.fail_result("sukuna_reverse_ritual should stay in candidate pool, not default loadout")
    if sukuna.candidate_skill_ids != PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku", "sukuna_reverse_ritual"]):
        return harness.fail_result("sukuna candidate skill pool should be structured as 解/捌/开/反转术式")
    if sukuna.ultimate_skill_id != "sukuna_fukuma_mizushi":
        return harness.fail_result("sukuna ultimate should stay fixed as 伏魔御厨子")
    if int(sukuna.ultimate_points_required) != 3 or int(sukuna.ultimate_points_cap) != 3:
        return harness.fail_result("sukuna ultimate point config should stay fixed as required=3 / cap=3")
    if sukuna.passive_skill_id != "sukuna_teach_love":
        return harness.fail_result("sukuna passive should stay fixed as 教会你爱的是...")
    if not content_index.skills.has("sukuna_reverse_ritual"):
        return harness.fail_result("sukuna candidate skill pool should retain 反转术式 for replacement tests")
    return harness.pass_result()

func _test_sukuna_matchup_regen_runtime_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 701)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    if sukuna_unit == null:
        return harness.fail_result("missing sukuna active unit")
    var regen_instances: Array = []
    for instance in sukuna_unit.rule_mod_instances:
        if instance.mod_kind == "mp_regen":
            regen_instances.append(instance)
    if regen_instances.size() != 1:
        return harness.fail_result("sukuna should receive exactly one matchup regen rule_mod on init")
    var expected_value := _resolve_matchup_gap_value(
        _sum_unit_bst(sukuna_unit),
        _sum_unit_bst(battle_state.get_side("P2").get_active_unit()),
        PackedInt32Array([20, 40, 70, 110, 160]),
        PackedInt32Array([9, 8, 7, 6, 5]),
        0
    )
    if int(regen_instances[0].value) != expected_value:
        return harness.fail_result("sukuna matchup regen rule_mod value mismatch: expected=%d actual=%d" % [expected_value, int(regen_instances[0].value)])
    var expected_current_mp: int = min(int(sukuna_unit.max_mp), int(content_index.units["sukuna"].init_mp) + expected_value)
    if int(sukuna_unit.current_mp) != expected_current_mp:
        return harness.fail_result("sukuna initial current_mp should reflect the matchup-based regen override value: expected=%d actual=%d" % [expected_current_mp, int(sukuna_unit.current_mp)])
    var regen_payload = content_index.effects["sukuna_refresh_love_regen"].payloads[0]
    if String(regen_payload.mod_op) != "set":
        return harness.fail_result("sukuna matchup regen payload should override regen with the matchup table value")
    if int(regen_payload.value) != 0:
        return harness.fail_result("runtime formula must not mutate shared rule_mod payload value")
    return harness.pass_result()

func _test_sukuna_reverse_ritual_heal_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var ritual_loadout := PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])
    var battle_setup = _build_sukuna_setup(sample_factory, {0: ritual_loadout})
    var battle_state = _build_battle_state(core, content_index, battle_setup, 702)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    if sukuna_unit == null:
        return harness.fail_result("missing sukuna active unit")
    if sukuna_unit.regular_skill_ids != ritual_loadout:
        return harness.fail_result("sukuna runtime loadout should mirror setup override")
    var legal_action_set = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if not legal_action_set.legal_skill_ids.has("sukuna_reverse_ritual"):
        return harness.fail_result("setup override should expose 反转术式 as legal action")
    if legal_action_set.legal_skill_ids.has("sukuna_hiraku"):
        return harness.fail_result("setup override should remove 开 from this battle loadout")
    sukuna_unit.current_hp = max(1, int(floor(float(sukuna_unit.max_hp) * 0.5)))
    var before_hp: int = sukuna_unit.current_hp
    var expected_gain: int = min(sukuna_unit.max_hp - before_hp, max(1, int(floor(float(sukuna_unit.max_hp) * 0.25))))
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_reverse_ritual",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    if sukuna_unit.current_hp - before_hp != expected_gain:
        return harness.fail_result("reverse ritual heal delta mismatch")
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_HEAL and String(log_event.payload_summary).find("heal") != -1:
            return harness.pass_result()
    return harness.fail_result("reverse ritual heal log missing")


func _build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
    return _support.build_sukuna_setup(sample_factory, p1_regular_skill_overrides)

func _build_battle_state(core, content_index, battle_setup, seed: int):
    return _support.build_battle_state(core, content_index, battle_setup, seed)

func _resolve_matchup_gap_value(owner_total: int, opponent_total: int, thresholds: PackedInt32Array, outputs: PackedInt32Array, default_value: int) -> int:
    return _support.resolve_matchup_gap_value(owner_total, opponent_total, thresholds, outputs, default_value)

func _sum_unit_bst(unit_state) -> int:
    return _support.sum_unit_bst(unit_state)
