extends RefCounted
class_name SukunaSetupRegenSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const SukunaTestSupportScript := preload("res://tests/support/sukuna_test_support.gd")

var _support = SukunaTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("sukuna_default_loadout_contract", failures, Callable(self, "_test_sukuna_default_loadout_contract").bind(harness))
    runner.run_test("sukuna_matchup_regen_runtime_path", failures, Callable(self, "_test_sukuna_matchup_regen_runtime_path").bind(harness))
    runner.run_test("sukuna_matchup_bst_includes_max_mp_contract", failures, Callable(self, "_test_sukuna_matchup_bst_includes_max_mp_contract").bind(harness))
    runner.run_test("sukuna_reverse_ritual_heal_path", failures, Callable(self, "_test_sukuna_reverse_ritual_heal_path").bind(harness))
    runner.run_test("sukuna_kai_priority_damage_contract", failures, Callable(self, "_test_sukuna_kai_priority_damage_contract").bind(harness))
    runner.run_test("sukuna_hatsu_mp_diff_contract", failures, Callable(self, "_test_sukuna_hatsu_mp_diff_contract").bind(harness))
    runner.run_test("sukuna_default_loadout_first_ultimate_window_contract", failures, Callable(self, "_test_sukuna_default_loadout_first_ultimate_window_contract").bind(harness))
    runner.run_test("sukuna_ritual_loadout_first_ultimate_window_contract", failures, Callable(self, "_test_sukuna_ritual_loadout_first_ultimate_window_contract").bind(harness))

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
    var expected_turn_regen: int = int(content_index.units["sukuna"].regen_per_turn) + expected_value
    var expected_current_mp: int = min(int(sukuna_unit.max_mp), int(content_index.units["sukuna"].init_mp) + expected_turn_regen)
    if int(sukuna_unit.current_mp) != expected_current_mp:
        return harness.fail_result("sukuna initial current_mp should reflect base regen plus matchup bonus: expected=%d actual=%d" % [expected_current_mp, int(sukuna_unit.current_mp)])
    var before_turn_mp: int = sukuna_unit.current_mp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 1, "P1", "P1-A"),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 2, "P1", "P1-A"),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    var expected_next_turn_mp: int = min(int(sukuna_unit.max_mp), before_turn_mp + expected_turn_regen)
    if int(sukuna_unit.current_mp) != expected_next_turn_mp:
        return harness.fail_result("sukuna next turn regen should keep base regen plus matchup bonus after the pre-applied first turn: expected=%d actual=%d" % [expected_next_turn_mp, int(sukuna_unit.current_mp)])
    var regen_payload = content_index.effects["sukuna_refresh_love_regen"].payloads[0]
    if String(regen_payload.mod_op) != "add":
        return harness.fail_result("sukuna matchup regen payload should add the matchup table value on top of base regen")
    if int(regen_payload.value) != 0:
        return harness.fail_result("runtime formula must not mutate shared rule_mod payload value")
    return harness.pass_result()

func _test_sukuna_matchup_bst_includes_max_mp_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var opponent_definition = content_index.units.get("sample_tidekit", null)
    if opponent_definition == null:
        return harness.fail_result("missing sample_tidekit unit definition")
    opponent_definition.max_mp = 250
    var battle_state = _build_battle_state(core, content_index, _build_sukuna_setup(sample_factory), 712)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var opponent_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or opponent_unit == null:
        return harness.fail_result("missing active units for matchup bst contract")
    if int(opponent_unit.max_mp) != 250:
        return harness.fail_result("runtime unit max_mp should mirror overridden content definition in this contract test")
    var regen_instance = null
    for instance in sukuna_unit.rule_mod_instances:
        if instance.mod_kind == "mp_regen":
            regen_instance = instance
            break
    if regen_instance == null:
        return harness.fail_result("sukuna matchup regen rule_mod missing")
    var thresholds := PackedInt32Array([20, 40, 70, 110, 160])
    var outputs := PackedInt32Array([9, 8, 7, 6, 5])
    var expected_with_max_mp := _resolve_matchup_gap_value(
        _sum_unit_bst(sukuna_unit),
        _sum_unit_bst(opponent_unit),
        thresholds,
        outputs,
        0
    )
    var expected_without_max_mp := _resolve_matchup_gap_value(
        _sum_unit_bst(sukuna_unit) - int(sukuna_unit.max_mp),
        _sum_unit_bst(opponent_unit) - int(opponent_unit.max_mp),
        thresholds,
        outputs,
        0
    )
    if expected_with_max_mp == expected_without_max_mp:
        return harness.fail_result("max_mp contract test must cross a gap band; current fixture no longer proves the seventh-dimension assumption")
    if int(regen_instance.value) != expected_with_max_mp:
        return harness.fail_result("sukuna matchup regen should use bst gap that includes max_mp: expected=%d actual=%d" % [expected_with_max_mp, int(regen_instance.value)])
    if int(regen_instance.value) == expected_without_max_mp:
        return harness.fail_result("sukuna matchup regen must not fall back to six-stat bst without max_mp")
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

func _test_sukuna_kai_priority_damage_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 707)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for sukuna kai contract")
    target_unit.base_speed = 999
    var skill_definition = content_index.skills["sukuna_kai"]
    var expected_damage = _calc_expected_damage(core, battle_state, sukuna_unit, target_unit, skill_definition, sukuna_unit.current_mp - skill_definition.mp_cost, target_unit.current_mp)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_kai"),
        _build_manual_skill_command(core, 1, "P2", "P2-A", "sample_strike"),
    ])
    var first_cast_actor_id := ""
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.ACTION_CAST:
            first_cast_actor_id = String(log_event.actor_id)
            break
    if first_cast_actor_id != sukuna_unit.unit_instance_id:
        return harness.fail_result("解应凭 priority=1 在更慢时仍先于普通技能行动")
    if target_unit.max_hp - target_unit.current_hp != expected_damage:
        return harness.fail_result("解的基础伤害口径漂移：expected=%d actual=%d" % [expected_damage, target_unit.max_hp - target_unit.current_hp])
    return harness.pass_result()

func _test_sukuna_hatsu_mp_diff_contract(harness) -> Dictionary:
    var low_result = _run_sukuna_hatsu_damage_case(harness, 708, 40, 40)
    if low_result.has("error"):
        return harness.fail_result(str(low_result["error"]))
    if int(low_result["damage"]) != int(low_result["expected_damage"]):
        return harness.fail_result("低 mp 差的 捌 伤害口径漂移：expected=%d actual=%d" % [int(low_result["expected_damage"]), int(low_result["damage"])])
    if int(low_result["power_bonus"]) != 0:
        return harness.fail_result("低 mp 差场景下，捌不应获得额外 power bonus")
    var high_result = _run_sukuna_hatsu_damage_case(harness, 709, 90, 20)
    if high_result.has("error"):
        return harness.fail_result(str(high_result["error"]))
    if int(high_result["damage"]) != int(high_result["expected_damage"]):
        return harness.fail_result("高 mp 差的 捌 伤害口径漂移：expected=%d actual=%d" % [int(high_result["expected_damage"]), int(high_result["damage"])])
    if int(high_result["power_bonus"]) <= 0:
        return harness.fail_result("高 mp 差场景下，捌应获得正的 power bonus")
    if int(high_result["damage"]) <= int(low_result["damage"]):
        return harness.fail_result("更高的 mp 差应让 捌 造成更高伤害")
    return harness.pass_result()

func _test_sukuna_default_loadout_first_ultimate_window_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = _build_battle_state(core, content_index, _build_sukuna_setup(sample_factory), 710)
    var window_turn = _simulate_until_ultimate_window(
        core,
        content_index,
        battle_state,
        func(turn_index: int):
            if turn_index <= 3:
                return _build_manual_skill_command(core, turn_index, "P1", "P1-A", "sukuna_kai")
            return _build_manual_wait_command(core, turn_index, "P1", "P1-A")
    )
    if window_turn != 4:
        return harness.fail_result("默认装配当前基准线的首次奥义窗口应固定在 turn 4，actual=%d" % window_turn)
    return harness.pass_result()

func _test_sukuna_ritual_loadout_first_ultimate_window_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var ritual_loadout := {0: PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])}
    var battle_state = _build_battle_state(core, content_index, _build_sukuna_setup(sample_factory, ritual_loadout), 711)
    var window_turn = _simulate_until_ultimate_window(
        core,
        content_index,
        battle_state,
        func(turn_index: int):
            if turn_index <= 3:
                return core.command_builder.build_command({
                    "turn_index": turn_index,
                    "command_type": CommandTypesScript.SKILL,
                    "command_source": "manual",
                    "side_id": "P1",
                    "actor_public_id": "P1-A",
                    "skill_id": "sukuna_reverse_ritual",
                })
            return _build_manual_wait_command(core, turn_index, "P1", "P1-A")
    )
    if window_turn != 4:
        return harness.fail_result("反转术式装配当前基准线的首次奥义窗口应固定在 turn 4，actual=%d" % window_turn)
    return harness.pass_result()


func _build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
    return _support.build_sukuna_setup(sample_factory, p1_regular_skill_overrides)

func _build_battle_state(core, content_index, battle_setup, seed: int):
    return _support.build_battle_state(core, content_index, battle_setup, seed)

func _resolve_matchup_gap_value(owner_total: int, opponent_total: int, thresholds: PackedInt32Array, outputs: PackedInt32Array, default_value: int) -> int:
    return _support.resolve_matchup_gap_value(owner_total, opponent_total, thresholds, outputs, default_value)

func _sum_unit_bst(unit_state) -> int:
    return _support.sum_unit_bst(unit_state)

func _run_sukuna_hatsu_damage_case(harness, seed: int, actor_mp_before_cast: int, target_mp_before_cast: int) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return {"error": str(core_payload["error"])}
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return {"error": "SampleBattleFactory init failed"}
    var content_index = harness.build_loaded_content_index(sample_factory)
    content_index.skills["sukuna_hatsu"].accuracy = 100
    var battle_state = _build_battle_state(core, content_index, _build_sukuna_setup(sample_factory), seed)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    sukuna_unit.current_mp = actor_mp_before_cast
    target_unit.current_mp = target_mp_before_cast
    var skill_definition = content_index.skills["sukuna_hatsu"]
    var actor_mp_after_cost: int = actor_mp_before_cast - skill_definition.mp_cost
    var power_bonus: int = max(0, actor_mp_after_cost - target_mp_before_cast)
    var expected_damage = _calc_expected_damage(core, battle_state, sukuna_unit, target_unit, skill_definition, actor_mp_after_cost, target_mp_before_cast)
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_hatsu"),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    return {
        "damage": target_unit.max_hp - target_unit.current_hp,
        "expected_damage": expected_damage,
        "power_bonus": power_bonus,
    }

func _calc_expected_damage(core, battle_state, actor, target, skill_definition, actor_mp_after_cost: int, target_mp_before_cast: int) -> int:
    var power_bonus := 0
    if String(skill_definition.power_bonus_source) == "mp_diff_clamped":
        power_bonus = max(0, actor_mp_after_cost - target_mp_before_cast)
    var power: int = int(skill_definition.power) + power_bonus
    var attack_value: int = core.stat_calculator.calc_effective_stat(actor.base_sp_attack, int(actor.stat_stages.get("sp_attack", 0))) if String(skill_definition.damage_kind) == "special" else core.stat_calculator.calc_effective_stat(actor.base_attack, int(actor.stat_stages.get("attack", 0)))
    var defense_value: int = core.stat_calculator.calc_effective_stat(target.base_sp_defense, int(target.stat_stages.get("sp_defense", 0))) if String(skill_definition.damage_kind) == "special" else core.stat_calculator.calc_effective_stat(target.base_defense, int(target.stat_stages.get("defense", 0)))
    var type_effectiveness: float = core.combat_type_service.calc_effectiveness(String(skill_definition.combat_type_id), target.combat_type_ids)
    var final_multiplier: float = core.rule_mod_service.get_final_multiplier(battle_state, actor.unit_instance_id)
    return core.damage_service.apply_final_mod(
        core.damage_service.calc_base_damage(
            battle_state.battle_level,
            power,
            attack_value,
            defense_value
        ),
        final_multiplier * type_effectiveness
    )

func _simulate_until_ultimate_window(core, content_index, battle_state, command_factory: Callable) -> int:
    for turn_index in range(1, 10):
        var legal_action_set = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
        if legal_action_set.legal_ultimate_ids.has("sukuna_fukuma_mizushi"):
            return turn_index
        core.turn_loop_controller.run_turn(battle_state, content_index, [
            command_factory.call(turn_index),
            _build_manual_wait_command(core, turn_index, "P2", "P2-A"),
        ])
        if battle_state.battle_result.finished:
            return -1
    return -1

func _build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return _support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)
