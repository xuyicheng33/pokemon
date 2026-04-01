extends RefCounted
class_name GojoSnapshotSuite

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("gojo_unit_snapshot_contract", failures, Callable(self, "_test_gojo_unit_snapshot_contract").bind(harness))
    runner.run_test("gojo_skill_snapshot_contract", failures, Callable(self, "_test_gojo_skill_snapshot_contract").bind(harness))
    runner.run_test("gojo_effect_snapshot_contract", failures, Callable(self, "_test_gojo_effect_snapshot_contract").bind(harness))

func _test_gojo_unit_snapshot_contract(harness) -> Dictionary:
    var content_index = _build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Gojo unit snapshot")
    var gojo = content_index.units.get("gojo_satoru", null)
    if gojo == null:
        return harness.fail_result("missing gojo unit definition")
    var checks: Array[Dictionary] = [
        {"label": "gojo display_name", "actual": String(gojo.display_name), "expected": "五条悟"},
        {"label": "gojo base_hp", "actual": int(gojo.base_hp), "expected": 124},
        {"label": "gojo base_attack", "actual": int(gojo.base_attack), "expected": 56},
        {"label": "gojo base_defense", "actual": int(gojo.base_defense), "expected": 60},
        {"label": "gojo base_sp_attack", "actual": int(gojo.base_sp_attack), "expected": 88},
        {"label": "gojo base_sp_defense", "actual": int(gojo.base_sp_defense), "expected": 68},
        {"label": "gojo base_speed", "actual": int(gojo.base_speed), "expected": 86},
        {"label": "gojo max_mp", "actual": int(gojo.max_mp), "expected": 100},
        {"label": "gojo init_mp", "actual": int(gojo.init_mp), "expected": 50},
        {"label": "gojo regen_per_turn", "actual": int(gojo.regen_per_turn), "expected": 14},
        {"label": "gojo ultimate_points_required", "actual": int(gojo.ultimate_points_required), "expected": 3},
        {"label": "gojo ultimate_points_cap", "actual": int(gojo.ultimate_points_cap), "expected": 3},
        {"label": "gojo ultimate_point_gain_on_regular_skill_cast", "actual": int(gojo.ultimate_point_gain_on_regular_skill_cast), "expected": 1},
        {"label": "gojo combat_type_ids", "actual": gojo.combat_type_ids, "expected": PackedStringArray(["space", "psychic"])},
        {"label": "gojo default skill_ids", "actual": gojo.skill_ids, "expected": PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki"])},
        {"label": "gojo candidate_skill_ids", "actual": gojo.candidate_skill_ids, "expected": PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki", "gojo_reverse_ritual"])},
        {"label": "gojo ultimate_skill_id", "actual": String(gojo.ultimate_skill_id), "expected": "gojo_unlimited_void"},
        {"label": "gojo passive_skill_id", "actual": String(gojo.passive_skill_id), "expected": "gojo_mugen"},
    ]
    return _run_checks(harness, checks)

func _test_gojo_skill_snapshot_contract(harness) -> Dictionary:
    var content_index = _build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Gojo skill snapshot")
    var checks: Array[Dictionary] = []
    var gojo_ao = content_index.skills.get("gojo_ao", null)
    var gojo_aka = content_index.skills.get("gojo_aka", null)
    var gojo_murasaki = content_index.skills.get("gojo_murasaki", null)
    var gojo_reverse = content_index.skills.get("gojo_reverse_ritual", null)
    var gojo_void = content_index.skills.get("gojo_unlimited_void", null)
    if gojo_ao == null or gojo_aka == null or gojo_murasaki == null or gojo_reverse == null or gojo_void == null:
        return harness.fail_result("missing gojo snapshot skill resource")
    checks.append_array([
        {"label": "gojo_ao damage_kind", "actual": String(gojo_ao.damage_kind), "expected": "special"},
        {"label": "gojo_ao power", "actual": int(gojo_ao.power), "expected": 44},
        {"label": "gojo_ao accuracy", "actual": int(gojo_ao.accuracy), "expected": 95},
        {"label": "gojo_ao mp_cost", "actual": int(gojo_ao.mp_cost), "expected": 14},
        {"label": "gojo_ao priority", "actual": int(gojo_ao.priority), "expected": 0},
        {"label": "gojo_ao combat_type_id", "actual": String(gojo_ao.combat_type_id), "expected": "space"},
        {"label": "gojo_ao targeting", "actual": String(gojo_ao.targeting), "expected": "enemy_active_slot"},
        {"label": "gojo_ao effects_on_hit_ids", "actual": gojo_ao.effects_on_hit_ids, "expected": PackedStringArray(["gojo_ao_speed_up", "gojo_ao_mark_apply"])},
        {"label": "gojo_aka damage_kind", "actual": String(gojo_aka.damage_kind), "expected": "special"},
        {"label": "gojo_aka power", "actual": int(gojo_aka.power), "expected": 44},
        {"label": "gojo_aka accuracy", "actual": int(gojo_aka.accuracy), "expected": 95},
        {"label": "gojo_aka mp_cost", "actual": int(gojo_aka.mp_cost), "expected": 14},
        {"label": "gojo_aka priority", "actual": int(gojo_aka.priority), "expected": 0},
        {"label": "gojo_aka combat_type_id", "actual": String(gojo_aka.combat_type_id), "expected": "psychic"},
        {"label": "gojo_aka targeting", "actual": String(gojo_aka.targeting), "expected": "enemy_active_slot"},
        {"label": "gojo_aka effects_on_hit_ids", "actual": gojo_aka.effects_on_hit_ids, "expected": PackedStringArray(["gojo_aka_slow_down", "gojo_aka_mark_apply"])},
        {"label": "gojo_murasaki damage_kind", "actual": String(gojo_murasaki.damage_kind), "expected": "special"},
        {"label": "gojo_murasaki power", "actual": int(gojo_murasaki.power), "expected": 64},
        {"label": "gojo_murasaki accuracy", "actual": int(gojo_murasaki.accuracy), "expected": 90},
        {"label": "gojo_murasaki mp_cost", "actual": int(gojo_murasaki.mp_cost), "expected": 24},
        {"label": "gojo_murasaki priority", "actual": int(gojo_murasaki.priority), "expected": -1},
        {"label": "gojo_murasaki combat_type_id", "actual": String(gojo_murasaki.combat_type_id), "expected": "space"},
        {"label": "gojo_murasaki targeting", "actual": String(gojo_murasaki.targeting), "expected": "enemy_active_slot"},
        {"label": "gojo_murasaki effects_on_hit_ids", "actual": gojo_murasaki.effects_on_hit_ids, "expected": PackedStringArray(["gojo_murasaki_conditional_burst"])},
        {"label": "gojo_reverse damage_kind", "actual": String(gojo_reverse.damage_kind), "expected": "none"},
        {"label": "gojo_reverse power", "actual": int(gojo_reverse.power), "expected": 0},
        {"label": "gojo_reverse accuracy", "actual": int(gojo_reverse.accuracy), "expected": 100},
        {"label": "gojo_reverse mp_cost", "actual": int(gojo_reverse.mp_cost), "expected": 14},
        {"label": "gojo_reverse priority", "actual": int(gojo_reverse.priority), "expected": 0},
        {"label": "gojo_reverse combat_type_id", "actual": String(gojo_reverse.combat_type_id), "expected": ""},
        {"label": "gojo_reverse targeting", "actual": String(gojo_reverse.targeting), "expected": "self"},
        {"label": "gojo_reverse effects_on_cast_ids", "actual": gojo_reverse.effects_on_cast_ids, "expected": PackedStringArray(["gojo_reverse_heal"])},
        {"label": "gojo_void damage_kind", "actual": String(gojo_void.damage_kind), "expected": "special"},
        {"label": "gojo_void power", "actual": int(gojo_void.power), "expected": 48},
        {"label": "gojo_void accuracy", "actual": int(gojo_void.accuracy), "expected": 100},
        {"label": "gojo_void mp_cost", "actual": int(gojo_void.mp_cost), "expected": 50},
        {"label": "gojo_void priority", "actual": int(gojo_void.priority), "expected": 5},
        {"label": "gojo_void combat_type_id", "actual": String(gojo_void.combat_type_id), "expected": "space"},
        {"label": "gojo_void targeting", "actual": String(gojo_void.targeting), "expected": "enemy_active_slot"},
        {"label": "gojo_void is_domain_skill", "actual": bool(gojo_void.is_domain_skill), "expected": true},
        {"label": "gojo_void effects_on_hit_ids", "actual": gojo_void.effects_on_hit_ids, "expected": PackedStringArray(["gojo_apply_domain_field"])},
    ])
    return _run_checks(harness, checks)

func _test_gojo_effect_snapshot_contract(harness) -> Dictionary:
    var content_index = _build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Gojo effect snapshot")
    var ao_mark = content_index.effects.get("gojo_ao_mark", null)
    var aka_mark = content_index.effects.get("gojo_aka_mark", null)
    var ao_speed = content_index.effects.get("gojo_ao_speed_up", null)
    var aka_slow = content_index.effects.get("gojo_aka_slow_down", null)
    var murasaki_burst = content_index.effects.get("gojo_murasaki_conditional_burst", null)
    var apply_domain = content_index.effects.get("gojo_apply_domain_field", null)
    var domain_lock = content_index.effects.get("gojo_domain_action_lock", null)
    var mugen_effect = content_index.effects.get("gojo_mugen_incoming_accuracy_down", null)
    var mugen = content_index.passive_skills.get("gojo_mugen", null)
    var domain_field = content_index.fields.get("gojo_unlimited_void_field", null)
    if ao_mark == null or aka_mark == null or ao_speed == null or aka_slow == null or murasaki_burst == null or apply_domain == null or domain_lock == null or mugen_effect == null or mugen == null or domain_field == null:
        return harness.fail_result("missing gojo snapshot effect resource")
    var ao_speed_payload = ao_speed.payloads[0]
    var aka_slow_payload = aka_slow.payloads[0]
    var burst_damage_payload = murasaki_burst.payloads[0]
    var burst_remove_ao = murasaki_burst.payloads[1]
    var burst_remove_aka = murasaki_burst.payloads[2]
    var apply_domain_payload = apply_domain.payloads[0]
    var domain_lock_payload = domain_lock.payloads[0]
    var mugen_payload = mugen_effect.payloads[0]
    var checks: Array[Dictionary] = [
        {"label": "gojo_ao_mark scope", "actual": String(ao_mark.scope), "expected": "self"},
        {"label": "gojo_ao_mark duration_mode", "actual": String(ao_mark.duration_mode), "expected": "turns"},
        {"label": "gojo_ao_mark duration", "actual": int(ao_mark.duration), "expected": 3},
        {"label": "gojo_ao_mark decrement_on", "actual": String(ao_mark.decrement_on), "expected": "turn_end"},
        {"label": "gojo_ao_mark stacking", "actual": String(ao_mark.stacking), "expected": "refresh"},
        {"label": "gojo_ao_mark persists_on_switch", "actual": bool(ao_mark.persists_on_switch), "expected": false},
        {"label": "gojo_aka_mark scope", "actual": String(aka_mark.scope), "expected": "self"},
        {"label": "gojo_aka_mark duration_mode", "actual": String(aka_mark.duration_mode), "expected": "turns"},
        {"label": "gojo_aka_mark duration", "actual": int(aka_mark.duration), "expected": 3},
        {"label": "gojo_aka_mark decrement_on", "actual": String(aka_mark.decrement_on), "expected": "turn_end"},
        {"label": "gojo_aka_mark stacking", "actual": String(aka_mark.stacking), "expected": "refresh"},
        {"label": "gojo_aka_mark persists_on_switch", "actual": bool(aka_mark.persists_on_switch), "expected": false},
        {"label": "gojo_ao_speed_up duration_mode", "actual": String(ao_speed.duration_mode), "expected": "permanent"},
        {"label": "gojo_ao_speed_up trigger_names", "actual": ao_speed.trigger_names, "expected": PackedStringArray(["on_hit"])},
        {"label": "gojo_ao_speed_up stat_name", "actual": String(ao_speed_payload.stat_name), "expected": "speed"},
        {"label": "gojo_ao_speed_up stage_delta", "actual": int(ao_speed_payload.stage_delta), "expected": 1},
        {"label": "gojo_aka_slow_down duration_mode", "actual": String(aka_slow.duration_mode), "expected": "permanent"},
        {"label": "gojo_aka_slow_down trigger_names", "actual": aka_slow.trigger_names, "expected": PackedStringArray(["on_hit"])},
        {"label": "gojo_aka_slow_down stat_name", "actual": String(aka_slow_payload.stat_name), "expected": "speed"},
        {"label": "gojo_aka_slow_down stage_delta", "actual": int(aka_slow_payload.stage_delta), "expected": -1},
        {"label": "gojo_murasaki_conditional_burst scope", "actual": String(murasaki_burst.scope), "expected": "target"},
        {"label": "gojo_murasaki_conditional_burst trigger_names", "actual": murasaki_burst.trigger_names, "expected": PackedStringArray(["on_hit"])},
        {"label": "gojo_murasaki_conditional_burst required_target_effects", "actual": murasaki_burst.required_target_effects, "expected": PackedStringArray(["gojo_ao_mark", "gojo_aka_mark"])},
        {"label": "gojo_murasaki_conditional_burst required_target_same_owner", "actual": bool(murasaki_burst.required_target_same_owner), "expected": true},
        {"label": "gojo_murasaki burst payload_type", "actual": String(burst_damage_payload.payload_type), "expected": "damage"},
        {"label": "gojo_murasaki burst use_formula", "actual": bool(burst_damage_payload.use_formula), "expected": true},
        {"label": "gojo_murasaki burst amount", "actual": int(burst_damage_payload.amount), "expected": 32},
        {"label": "gojo_murasaki burst damage_kind", "actual": String(burst_damage_payload.damage_kind), "expected": "special"},
        {"label": "gojo_murasaki remove ao payload", "actual": String(burst_remove_ao.effect_definition_id), "expected": "gojo_ao_mark"},
        {"label": "gojo_murasaki remove aka payload", "actual": String(burst_remove_aka.effect_definition_id), "expected": "gojo_aka_mark"},
        {"label": "gojo_apply_domain_field duration_mode", "actual": String(apply_domain.duration_mode), "expected": "turns"},
        {"label": "gojo_apply_domain_field duration", "actual": int(apply_domain.duration), "expected": 3},
        {"label": "gojo_apply_domain_field decrement_on", "actual": String(apply_domain.decrement_on), "expected": "turn_end"},
        {"label": "gojo_apply_domain_field trigger_names", "actual": apply_domain.trigger_names, "expected": PackedStringArray(["on_hit"])},
        {"label": "gojo_apply_domain_field field_definition_id", "actual": String(apply_domain_payload.field_definition_id), "expected": "gojo_unlimited_void_field"},
        {"label": "gojo_apply_domain_field on_success_effect_ids", "actual": apply_domain_payload.on_success_effect_ids, "expected": PackedStringArray(["gojo_domain_action_lock"])},
        {"label": "gojo_unlimited_void_field effect_ids", "actual": domain_field.effect_ids, "expected": PackedStringArray(["gojo_domain_cast_buff"])},
        {"label": "gojo_unlimited_void_field on_expire_effect_ids", "actual": domain_field.on_expire_effect_ids, "expected": PackedStringArray(["gojo_domain_buff_remove"])},
        {"label": "gojo_unlimited_void_field on_break_effect_ids", "actual": domain_field.on_break_effect_ids, "expected": PackedStringArray(["gojo_domain_buff_remove"])},
        {"label": "gojo_unlimited_void_field creator_accuracy_override", "actual": int(domain_field.creator_accuracy_override), "expected": 100},
        {"label": "gojo_domain_action_lock trigger_names", "actual": domain_lock.trigger_names, "expected": PackedStringArray(["field_apply_success"])},
        {"label": "gojo_domain_action_lock mod_kind", "actual": String(domain_lock_payload.mod_kind), "expected": "action_legality"},
        {"label": "gojo_domain_action_lock mod_op", "actual": String(domain_lock_payload.mod_op), "expected": "deny"},
        {"label": "gojo_domain_action_lock value", "actual": String(domain_lock_payload.value), "expected": "all"},
        {"label": "gojo_domain_action_lock duration_mode", "actual": String(domain_lock_payload.duration_mode), "expected": "turns"},
        {"label": "gojo_domain_action_lock duration", "actual": int(domain_lock_payload.duration), "expected": 1},
        {"label": "gojo_domain_action_lock decrement_on", "actual": String(domain_lock_payload.decrement_on), "expected": "turn_end"},
        {"label": "gojo_mugen trigger_names", "actual": mugen.trigger_names, "expected": PackedStringArray(["on_enter"])},
        {"label": "gojo_mugen effect_ids", "actual": mugen.effect_ids, "expected": PackedStringArray(["gojo_mugen_incoming_accuracy_down"])},
        {"label": "gojo_mugen_incoming_accuracy_down trigger_names", "actual": mugen_effect.trigger_names, "expected": PackedStringArray(["on_enter"])},
        {"label": "gojo_mugen incoming_accuracy mod_kind", "actual": String(mugen_payload.mod_kind), "expected": "incoming_accuracy"},
        {"label": "gojo_mugen incoming_accuracy mod_op", "actual": String(mugen_payload.mod_op), "expected": "add"},
        {"label": "gojo_mugen incoming_accuracy value", "actual": int(mugen_payload.value), "expected": -10},
        {"label": "gojo_mugen incoming_accuracy scope", "actual": String(mugen_payload.scope), "expected": "self"},
        {"label": "gojo_mugen incoming_accuracy duration_mode", "actual": String(mugen_payload.duration_mode), "expected": "permanent"},
    ]
    return _run_checks(harness, checks)

func _build_content_index(harness):
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return null
    return harness.build_loaded_content_index(sample_factory)

func _run_checks(harness, checks: Array[Dictionary]) -> Dictionary:
    for check in checks:
        if check["actual"] != check["expected"]:
            return harness.fail_result("%s expected=%s actual=%s" % [
                String(check["label"]),
                var_to_str(check["expected"]),
                var_to_str(check["actual"]),
            ])
    return harness.pass_result()
