extends RefCounted
class_name ObitoSnapshotSuite

const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")

var _support = ObitoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("obito_unit_snapshot_contract", failures, Callable(self, "_test_obito_unit_snapshot_contract").bind(harness))
    runner.run_test("obito_skill_snapshot_contract", failures, Callable(self, "_test_obito_skill_snapshot_contract").bind(harness))
    runner.run_test("obito_effect_snapshot_contract", failures, Callable(self, "_test_obito_effect_snapshot_contract").bind(harness))
    runner.run_test("obito_candidate_loadout_contract", failures, Callable(self, "_test_obito_candidate_loadout_contract").bind(harness))

func _test_obito_unit_snapshot_contract(harness) -> Dictionary:
    var content_index = _build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Obito unit snapshot")
    var obito = content_index.units.get("obito_juubi_jinchuriki", null)
    if obito == null:
        return harness.fail_result("missing obito unit definition")
    var checks: Array[Dictionary] = [
        {"label": "obito display_name", "actual": String(obito.display_name), "expected": "宇智波带土·十尾人柱力"},
        {"label": "obito base_hp", "actual": int(obito.base_hp), "expected": 128},
        {"label": "obito base_attack", "actual": int(obito.base_attack), "expected": 58},
        {"label": "obito base_defense", "actual": int(obito.base_defense), "expected": 78},
        {"label": "obito base_sp_attack", "actual": int(obito.base_sp_attack), "expected": 88},
        {"label": "obito base_sp_defense", "actual": int(obito.base_sp_defense), "expected": 80},
        {"label": "obito base_speed", "actual": int(obito.base_speed), "expected": 64},
        {"label": "obito max_mp", "actual": int(obito.max_mp), "expected": 100},
        {"label": "obito init_mp", "actual": int(obito.init_mp), "expected": 48},
        {"label": "obito regen_per_turn", "actual": int(obito.regen_per_turn), "expected": 12},
        {"label": "obito ultimate_points_required", "actual": int(obito.ultimate_points_required), "expected": 3},
        {"label": "obito ultimate_points_cap", "actual": int(obito.ultimate_points_cap), "expected": 3},
        {"label": "obito ultimate_point_gain_on_regular_skill_cast", "actual": int(obito.ultimate_point_gain_on_regular_skill_cast), "expected": 1},
        {"label": "obito combat_type_ids", "actual": obito.combat_type_ids, "expected": PackedStringArray(["light", "dark"])},
        {"label": "obito skill_ids", "actual": obito.skill_ids, "expected": PackedStringArray(["obito_qiudao_jiaotu", "obito_yinyang_dun", "obito_qiudao_yu"])},
        {"label": "obito candidate_skill_ids", "actual": obito.candidate_skill_ids, "expected": PackedStringArray(["obito_qiudao_jiaotu", "obito_yinyang_dun", "obito_qiudao_yu", "obito_liudao_shizi_fenghuo"])},
        {"label": "obito ultimate_skill_id", "actual": String(obito.ultimate_skill_id), "expected": "obito_shiwei_weishouyu"},
        {"label": "obito passive_skill_id", "actual": String(obito.passive_skill_id), "expected": "obito_xianren_zhili"},
    ]
    return _run_checks(harness, checks)

func _test_obito_skill_snapshot_contract(harness) -> Dictionary:
    var content_index = _build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Obito skill snapshot")
    var jiaotu = content_index.skills.get("obito_qiudao_jiaotu", null)
    var yinyang_dun = content_index.skills.get("obito_yinyang_dun", null)
    var qiudao_yu = content_index.skills.get("obito_qiudao_yu", null)
    var fenghuo = content_index.skills.get("obito_liudao_shizi_fenghuo", null)
    var ultimate = content_index.skills.get("obito_shiwei_weishouyu", null)
    if jiaotu == null or yinyang_dun == null or qiudao_yu == null or fenghuo == null or ultimate == null:
        return harness.fail_result("missing obito snapshot skill resource")
    var checks: Array[Dictionary] = [
        {"label": "obito_qiudao_jiaotu damage_kind", "actual": String(jiaotu.damage_kind), "expected": "special"},
        {"label": "obito_qiudao_jiaotu power", "actual": int(jiaotu.power), "expected": 42},
        {"label": "obito_qiudao_jiaotu accuracy", "actual": int(jiaotu.accuracy), "expected": 100},
        {"label": "obito_qiudao_jiaotu mp_cost", "actual": int(jiaotu.mp_cost), "expected": 10},
        {"label": "obito_qiudao_jiaotu priority", "actual": int(jiaotu.priority), "expected": 0},
        {"label": "obito_qiudao_jiaotu effects_on_hit_ids", "actual": jiaotu.effects_on_hit_ids, "expected": PackedStringArray(["obito_qiudao_jiaotu_heal_block_apply", "obito_qiudao_jiaotu_heal_block_rule_mod"])},
        {"label": "obito_yinyang_dun damage_kind", "actual": String(yinyang_dun.damage_kind), "expected": "none"},
        {"label": "obito_yinyang_dun targeting", "actual": String(yinyang_dun.targeting), "expected": "self"},
        {"label": "obito_yinyang_dun mp_cost", "actual": int(yinyang_dun.mp_cost), "expected": 16},
        {"label": "obito_yinyang_dun priority", "actual": int(yinyang_dun.priority), "expected": 2},
        {"label": "obito_yinyang_dun effects_on_cast_ids", "actual": yinyang_dun.effects_on_cast_ids, "expected": PackedStringArray(["obito_yinyang_dun_boost_and_charge", "obito_yinyang_dun_guard_rule_mod", "obito_yinyang_dun_guard_stack_listener"])},
        {"label": "obito_qiudao_yu power", "actual": int(qiudao_yu.power), "expected": 24},
        {"label": "obito_qiudao_yu combat_type_id", "actual": String(qiudao_yu.combat_type_id), "expected": "light"},
        {"label": "obito_qiudao_yu power_bonus_source", "actual": String(qiudao_yu.power_bonus_source), "expected": "effect_stack_sum"},
        {"label": "obito_qiudao_yu power_bonus_self_effect_ids", "actual": qiudao_yu.power_bonus_self_effect_ids, "expected": PackedStringArray(["obito_yinyang_zhili"])},
        {"label": "obito_qiudao_yu power_bonus_per_stack", "actual": int(qiudao_yu.power_bonus_per_stack), "expected": 12},
        {"label": "obito_qiudao_yu execute_target_hp_ratio_lte", "actual": float(qiudao_yu.execute_target_hp_ratio_lte), "expected": 0.3},
        {"label": "obito_qiudao_yu execute_required_total_stacks", "actual": int(qiudao_yu.execute_required_total_stacks), "expected": 5},
        {"label": "obito_qiudao_yu execute_self_effect_ids", "actual": qiudao_yu.execute_self_effect_ids, "expected": PackedStringArray(["obito_yinyang_zhili"])},
        {"label": "obito_qiudao_yu effects_on_hit_ids", "actual": qiudao_yu.effects_on_hit_ids, "expected": PackedStringArray(["obito_qiudao_yu_clear_yinyang"])},
        {"label": "obito_qiudao_yu effects_on_miss_ids", "actual": qiudao_yu.effects_on_miss_ids, "expected": PackedStringArray(["obito_qiudao_yu_clear_yinyang"])},
        {"label": "obito_liudao_shizi_fenghuo power", "actual": int(fenghuo.power), "expected": 62},
        {"label": "obito_liudao_shizi_fenghuo accuracy", "actual": int(fenghuo.accuracy), "expected": 90},
        {"label": "obito_liudao_shizi_fenghuo mp_cost", "actual": int(fenghuo.mp_cost), "expected": 24},
        {"label": "obito_liudao_shizi_fenghuo priority", "actual": int(fenghuo.priority), "expected": -1},
        {"label": "obito_shiwei_weishouyu accuracy", "actual": int(ultimate.accuracy), "expected": 100},
        {"label": "obito_shiwei_weishouyu mp_cost", "actual": int(ultimate.mp_cost), "expected": 50},
        {"label": "obito_shiwei_weishouyu priority", "actual": int(ultimate.priority), "expected": 5},
        {"label": "obito_shiwei_weishouyu segment_count", "actual": int(ultimate.damage_segments.size()), "expected": 2},
    ]
    return _run_checks(harness, checks)

func _test_obito_effect_snapshot_contract(harness) -> Dictionary:
    var content_index = _build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Obito effect snapshot")
    var heal = content_index.effects.get("obito_xianren_zhili_heal", null)
    var yinyang = content_index.effects.get("obito_yinyang_zhili", null)
    var mark = content_index.effects.get("obito_qiudao_jiaotu_heal_block_mark", null)
    var mark_apply = content_index.effects.get("obito_qiudao_jiaotu_heal_block_apply", null)
    var rule_mod = content_index.effects.get("obito_qiudao_jiaotu_heal_block_rule_mod", null)
    var boost = content_index.effects.get("obito_yinyang_dun_boost_and_charge", null)
    var guard = content_index.effects.get("obito_yinyang_dun_guard_rule_mod", null)
    var listener_apply = content_index.effects.get("obito_yinyang_dun_guard_stack_listener", null)
    var listener_state = content_index.effects.get("obito_yinyang_dun_guard_stack_listener_state", null)
    var clear = content_index.effects.get("obito_qiudao_yu_clear_yinyang", null)
    var passive = content_index.passive_skills.get("obito_xianren_zhili", null)
    if heal == null or yinyang == null or mark == null or mark_apply == null or rule_mod == null or boost == null or guard == null or listener_apply == null or listener_state == null or clear == null or passive == null:
        return harness.fail_result("missing obito snapshot effect resource")
    var heal_payload = heal.payloads[0]
    var mark_apply_payload = mark_apply.payloads[0]
    var rule_mod_payload = rule_mod.payloads[0]
    var boost_apply_payload = boost.payloads[0]
    var boost_def_payload = boost.payloads[1]
    var boost_sp_def_payload = boost.payloads[2]
    var guard_payload = guard.payloads[0]
    var listener_apply_payload = listener_apply.payloads[0]
    var listener_state_payload = listener_state.payloads[0]
    var clear_payload = clear.payloads[0]
    var checks: Array[Dictionary] = [
        {"label": "obito passive.trigger_names", "actual": passive.trigger_names, "expected": PackedStringArray(["turn_start"])},
        {"label": "obito passive.effect_ids", "actual": passive.effect_ids, "expected": PackedStringArray(["obito_xianren_zhili_heal"])},
        {"label": "obito_xianren_zhili_heal trigger_names", "actual": heal.trigger_names, "expected": PackedStringArray(["turn_start"])},
        {"label": "obito_xianren_zhili_heal percent", "actual": int(heal_payload.percent), "expected": 10},
        {"label": "obito_xianren_zhili_heal percent_base", "actual": String(heal_payload.percent_base), "expected": "missing_hp"},
        {"label": "obito_yinyang_zhili stacking", "actual": String(yinyang.stacking), "expected": "stack"},
        {"label": "obito_yinyang_zhili max_stacks", "actual": int(yinyang.max_stacks), "expected": 5},
        {"label": "obito_qiudao_jiaotu_mark duration", "actual": int(mark.duration), "expected": 2},
        {"label": "obito_qiudao_jiaotu_mark decrement_on", "actual": String(mark.decrement_on), "expected": "turn_end"},
        {"label": "obito_qiudao_jiaotu_mark persists_on_switch", "actual": bool(mark.persists_on_switch), "expected": true},
        {"label": "obito_qiudao_jiaotu_mark_apply trigger_names", "actual": mark_apply.trigger_names, "expected": PackedStringArray(["on_hit"])},
        {"label": "obito_qiudao_jiaotu_mark_apply target", "actual": String(mark_apply_payload.effect_definition_id), "expected": "obito_qiudao_jiaotu_heal_block_mark"},
        {"label": "obito_qiudao_jiaotu_rule_mod duration", "actual": int(rule_mod.duration), "expected": 2},
        {"label": "obito_qiudao_jiaotu_rule_mod decrement_on", "actual": String(rule_mod.decrement_on), "expected": "turn_end"},
        {"label": "obito_qiudao_jiaotu_rule_mod persists_on_switch", "actual": bool(rule_mod.persists_on_switch), "expected": true},
        {"label": "obito_qiudao_jiaotu_rule_mod kind", "actual": String(rule_mod_payload.mod_kind), "expected": "incoming_heal_final_mod"},
        {"label": "obito_qiudao_jiaotu_rule_mod op", "actual": String(rule_mod_payload.mod_op), "expected": "set"},
        {"label": "obito_qiudao_jiaotu_rule_mod value", "actual": float(rule_mod_payload.value), "expected": 0.0},
        {"label": "obito_qiudao_jiaotu_rule_mod scope", "actual": String(rule_mod_payload.scope), "expected": "target"},
        {"label": "obito_yinyang_boost target", "actual": String(boost_apply_payload.effect_definition_id), "expected": "obito_yinyang_zhili"},
        {"label": "obito_yinyang_boost def", "actual": String(boost_def_payload.stat_name), "expected": "defense"},
        {"label": "obito_yinyang_boost def stage", "actual": int(boost_def_payload.stage_delta), "expected": 1},
        {"label": "obito_yinyang_boost sp_def", "actual": String(boost_sp_def_payload.stat_name), "expected": "sp_defense"},
        {"label": "obito_yinyang_boost sp_def stage", "actual": int(boost_sp_def_payload.stage_delta), "expected": 1},
        {"label": "obito_yinyang_guard trigger_names", "actual": guard.trigger_names, "expected": PackedStringArray(["on_cast"])},
        {"label": "obito_yinyang_guard mod_kind", "actual": String(guard_payload.mod_kind), "expected": "incoming_action_final_mod"},
        {"label": "obito_yinyang_guard mod_op", "actual": String(guard_payload.mod_op), "expected": "mul"},
        {"label": "obito_yinyang_guard value", "actual": float(guard_payload.value), "expected": 0.5},
        {"label": "obito_yinyang_guard command_filters", "actual": guard_payload.required_incoming_command_types, "expected": PackedStringArray(["skill", "ultimate"])},
        {"label": "obito_yinyang_listener_apply trigger_names", "actual": listener_apply.trigger_names, "expected": PackedStringArray(["on_cast"])},
        {"label": "obito_yinyang_listener_apply target", "actual": String(listener_apply_payload.effect_definition_id), "expected": "obito_yinyang_dun_guard_stack_listener_state"},
        {"label": "obito_yinyang_listener_state trigger_names", "actual": listener_state.trigger_names, "expected": PackedStringArray(["on_receive_action_damage_segment"])},
        {"label": "obito_yinyang_listener_state duration", "actual": int(listener_state.duration), "expected": 1},
        {"label": "obito_yinyang_listener_state decrement_on", "actual": String(listener_state.decrement_on), "expected": "turn_end"},
        {"label": "obito_yinyang_listener_state apply target", "actual": String(listener_state_payload.effect_definition_id), "expected": "obito_yinyang_zhili"},
        {"label": "obito_qiudao_yu_clear trigger_names", "actual": clear.trigger_names, "expected": PackedStringArray(["on_hit", "on_miss"])},
        {"label": "obito_qiudao_yu_clear effect_definition_id", "actual": String(clear_payload.effect_definition_id), "expected": "obito_yinyang_zhili"},
        {"label": "obito_qiudao_yu_clear remove_mode", "actual": String(clear_payload.remove_mode), "expected": "all"},
    ]
    return _run_checks(harness, checks)

func _test_obito_candidate_loadout_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var override_loadout := PackedStringArray(["obito_qiudao_jiaotu", "obito_yinyang_dun", "obito_liudao_shizi_fenghuo"])
    var battle_setup = _support.build_obito_setup(sample_factory, {0: override_loadout})
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1501, battle_setup)
    var obito = battle_state.get_side("P1").get_active_unit()
    if obito == null:
        return harness.fail_result("missing obito active unit for candidate loadout contract")
    if obito.regular_skill_ids != override_loadout:
        return harness.fail_result("obito runtime regular_skill_ids should use setup override")
    var legal_action_set = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
    if not legal_action_set.legal_skill_ids.has("obito_liudao_shizi_fenghuo"):
        return harness.fail_result("obito override loadout should expose swapped-in candidate skill")
    if legal_action_set.legal_skill_ids.has("obito_qiudao_yu"):
        return harness.fail_result("obito override loadout should hide swapped-out default skill")
    return harness.pass_result()

func _build_content_index(harness):
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return null
    return harness.build_loaded_content_index(sample_factory)

func _run_checks(harness, checks: Array[Dictionary]) -> Dictionary:
    var failures: Array[String] = []
    for check in checks:
        if check["actual"] != check["expected"]:
            failures.append("%s expected=%s actual=%s" % [
                String(check["label"]),
                var_to_str(check["expected"]),
                var_to_str(check["actual"]),
            ])
    if not failures.is_empty():
        return harness.fail_result("\n".join(failures))
    return harness.pass_result()
