extends RefCounted
class_name SukunaSnapshotSuite

const FormalCharacterSnapshotTestHelperScript := preload("res://tests/support/formal_character_snapshot_test_helper.gd")

var _helper = FormalCharacterSnapshotTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("sukuna_unit_snapshot_contract", failures, Callable(self, "_test_sukuna_unit_snapshot_contract").bind(harness))
    runner.run_test("sukuna_skill_snapshot_contract", failures, Callable(self, "_test_sukuna_skill_snapshot_contract").bind(harness))
    runner.run_test("sukuna_effect_snapshot_contract", failures, Callable(self, "_test_sukuna_effect_snapshot_contract").bind(harness))

func _test_sukuna_unit_snapshot_contract(harness) -> Dictionary:
    var content_index = _helper.build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Sukuna unit snapshot")
    var sukuna = content_index.units.get("sukuna", null)
    if sukuna == null:
        return harness.fail_result("missing sukuna unit definition")
    var checks: Array[Dictionary] = [
        {"label": "sukuna display_name", "actual": String(sukuna.display_name), "expected": "宿傩"},
        {"label": "sukuna base_hp", "actual": int(sukuna.base_hp), "expected": 126},
        {"label": "sukuna base_attack", "actual": int(sukuna.base_attack), "expected": 78},
        {"label": "sukuna base_defense", "actual": int(sukuna.base_defense), "expected": 62},
        {"label": "sukuna base_sp_attack", "actual": int(sukuna.base_sp_attack), "expected": 84},
        {"label": "sukuna base_sp_defense", "actual": int(sukuna.base_sp_defense), "expected": 60},
        {"label": "sukuna base_speed", "actual": int(sukuna.base_speed), "expected": 76},
        {"label": "sukuna max_mp", "actual": int(sukuna.max_mp), "expected": 100},
        {"label": "sukuna init_mp", "actual": int(sukuna.init_mp), "expected": 45},
        {"label": "sukuna regen_per_turn", "actual": int(sukuna.regen_per_turn), "expected": 12},
        {"label": "sukuna ultimate_points_required", "actual": int(sukuna.ultimate_points_required), "expected": 3},
        {"label": "sukuna ultimate_points_cap", "actual": int(sukuna.ultimate_points_cap), "expected": 3},
        {"label": "sukuna ultimate_point_gain_on_regular_skill_cast", "actual": int(sukuna.ultimate_point_gain_on_regular_skill_cast), "expected": 1},
        {"label": "sukuna combat_type_ids", "actual": sukuna.combat_type_ids, "expected": PackedStringArray(["fire", "demon"])},
        {"label": "sukuna default skill_ids", "actual": sukuna.skill_ids, "expected": PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku"])},
        {"label": "sukuna candidate_skill_ids", "actual": sukuna.candidate_skill_ids, "expected": PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku", "sukuna_reverse_ritual"])},
        {"label": "sukuna ultimate_skill_id", "actual": String(sukuna.ultimate_skill_id), "expected": "sukuna_fukuma_mizushi"},
        {"label": "sukuna passive_skill_id", "actual": String(sukuna.passive_skill_id), "expected": "sukuna_teach_love"},
    ]
    return _helper.run_checks(harness, checks)

func _test_sukuna_skill_snapshot_contract(harness) -> Dictionary:
    var content_index = _helper.build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Sukuna skill snapshot")
    var sukuna_kai = content_index.skills.get("sukuna_kai", null)
    var sukuna_hatsu = content_index.skills.get("sukuna_hatsu", null)
    var sukuna_hiraku = content_index.skills.get("sukuna_hiraku", null)
    var sukuna_reverse = content_index.skills.get("sukuna_reverse_ritual", null)
    var sukuna_domain = content_index.skills.get("sukuna_fukuma_mizushi", null)
    if sukuna_kai == null or sukuna_hatsu == null or sukuna_hiraku == null or sukuna_reverse == null or sukuna_domain == null:
        return harness.fail_result("missing sukuna snapshot skill resource")
    var checks: Array[Dictionary] = [
        {"label": "sukuna_kai damage_kind", "actual": String(sukuna_kai.damage_kind), "expected": "physical"},
        {"label": "sukuna_kai power", "actual": int(sukuna_kai.power), "expected": 42},
        {"label": "sukuna_kai accuracy", "actual": int(sukuna_kai.accuracy), "expected": 100},
        {"label": "sukuna_kai mp_cost", "actual": int(sukuna_kai.mp_cost), "expected": 10},
        {"label": "sukuna_kai priority", "actual": int(sukuna_kai.priority), "expected": 1},
        {"label": "sukuna_kai combat_type_id", "actual": String(sukuna_kai.combat_type_id), "expected": ""},
        {"label": "sukuna_kai targeting", "actual": String(sukuna_kai.targeting), "expected": "enemy_active_slot"},
        {"label": "sukuna_hatsu damage_kind", "actual": String(sukuna_hatsu.damage_kind), "expected": "special"},
        {"label": "sukuna_hatsu power", "actual": int(sukuna_hatsu.power), "expected": 46},
        {"label": "sukuna_hatsu accuracy", "actual": int(sukuna_hatsu.accuracy), "expected": 95},
        {"label": "sukuna_hatsu mp_cost", "actual": int(sukuna_hatsu.mp_cost), "expected": 18},
        {"label": "sukuna_hatsu priority", "actual": int(sukuna_hatsu.priority), "expected": -1},
        {"label": "sukuna_hatsu combat_type_id", "actual": String(sukuna_hatsu.combat_type_id), "expected": ""},
        {"label": "sukuna_hatsu targeting", "actual": String(sukuna_hatsu.targeting), "expected": "enemy_active_slot"},
        {"label": "sukuna_hatsu power_bonus_source", "actual": String(sukuna_hatsu.power_bonus_source), "expected": "mp_diff_clamped"},
        {"label": "sukuna_hiraku damage_kind", "actual": String(sukuna_hiraku.damage_kind), "expected": "special"},
        {"label": "sukuna_hiraku power", "actual": int(sukuna_hiraku.power), "expected": 48},
        {"label": "sukuna_hiraku accuracy", "actual": int(sukuna_hiraku.accuracy), "expected": 90},
        {"label": "sukuna_hiraku mp_cost", "actual": int(sukuna_hiraku.mp_cost), "expected": 22},
        {"label": "sukuna_hiraku priority", "actual": int(sukuna_hiraku.priority), "expected": -2},
        {"label": "sukuna_hiraku combat_type_id", "actual": String(sukuna_hiraku.combat_type_id), "expected": "fire"},
        {"label": "sukuna_hiraku targeting", "actual": String(sukuna_hiraku.targeting), "expected": "enemy_active_slot"},
        {"label": "sukuna_hiraku effects_on_hit_ids", "actual": sukuna_hiraku.effects_on_hit_ids, "expected": PackedStringArray(["sukuna_apply_kamado"])},
        {"label": "sukuna_reverse damage_kind", "actual": String(sukuna_reverse.damage_kind), "expected": "none"},
        {"label": "sukuna_reverse power", "actual": int(sukuna_reverse.power), "expected": 0},
        {"label": "sukuna_reverse accuracy", "actual": int(sukuna_reverse.accuracy), "expected": 100},
        {"label": "sukuna_reverse mp_cost", "actual": int(sukuna_reverse.mp_cost), "expected": 14},
        {"label": "sukuna_reverse priority", "actual": int(sukuna_reverse.priority), "expected": 0},
        {"label": "sukuna_reverse combat_type_id", "actual": String(sukuna_reverse.combat_type_id), "expected": ""},
        {"label": "sukuna_reverse targeting", "actual": String(sukuna_reverse.targeting), "expected": "self"},
        {"label": "sukuna_reverse effects_on_cast_ids", "actual": sukuna_reverse.effects_on_cast_ids, "expected": PackedStringArray(["sukuna_reverse_heal"])},
        {"label": "sukuna_domain damage_kind", "actual": String(sukuna_domain.damage_kind), "expected": "special"},
        {"label": "sukuna_domain power", "actual": int(sukuna_domain.power), "expected": 68},
        {"label": "sukuna_domain accuracy", "actual": int(sukuna_domain.accuracy), "expected": 100},
        {"label": "sukuna_domain mp_cost", "actual": int(sukuna_domain.mp_cost), "expected": 50},
        {"label": "sukuna_domain priority", "actual": int(sukuna_domain.priority), "expected": 5},
        {"label": "sukuna_domain combat_type_id", "actual": String(sukuna_domain.combat_type_id), "expected": "demon"},
        {"label": "sukuna_domain targeting", "actual": String(sukuna_domain.targeting), "expected": "enemy_active_slot"},
        {"label": "sukuna_domain is_domain_skill", "actual": bool(sukuna_domain.is_domain_skill), "expected": true},
        {"label": "sukuna_domain effects_on_hit_ids", "actual": sukuna_domain.effects_on_hit_ids, "expected": PackedStringArray(["sukuna_apply_domain_field"])},
    ]
    return _helper.run_checks(harness, checks)

func _test_sukuna_effect_snapshot_contract(harness) -> Dictionary:
    var content_index = _helper.build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Sukuna effect snapshot")
    var apply_kamado = content_index.effects.get("sukuna_apply_kamado", null)
    var kamado_mark = content_index.effects.get("sukuna_kamado_mark", null)
    var kamado_explode = content_index.effects.get("sukuna_kamado_explode", null)
    var apply_domain = content_index.effects.get("sukuna_apply_domain_field", null)
    var domain_cast_buff = content_index.effects.get("sukuna_domain_cast_buff", null)
    var domain_buff_remove = content_index.effects.get("sukuna_domain_buff_remove", null)
    var domain_expire_burst = content_index.effects.get("sukuna_domain_expire_burst", null)
    var regen_effect = content_index.effects.get("sukuna_refresh_love_regen", null)
    var passive_skill = content_index.passive_skills.get("sukuna_teach_love", null)
    var domain_field = content_index.fields.get("sukuna_malevolent_shrine_field", null)
    if apply_kamado == null or kamado_mark == null or kamado_explode == null or apply_domain == null or domain_cast_buff == null or domain_buff_remove == null or domain_expire_burst == null or regen_effect == null or passive_skill == null or domain_field == null:
        return harness.fail_result("missing sukuna snapshot effect resource")
    var apply_kamado_payload = apply_kamado.payloads[0]
    var kamado_payload = kamado_mark.payloads[0]
    var kamado_expire_payload = kamado_explode.payloads[0]
    var apply_domain_payload = apply_domain.payloads[0]
    var domain_attack_payload = domain_cast_buff.payloads[0]
    var domain_sp_attack_payload = domain_cast_buff.payloads[1]
    var domain_remove_attack_payload = domain_buff_remove.payloads[0]
    var domain_remove_sp_attack_payload = domain_buff_remove.payloads[1]
    var domain_expire_payload = domain_expire_burst.payloads[0]
    var regen_payload = regen_effect.payloads[0]
    var checks: Array[Dictionary] = [
        {"label": "sukuna_apply_kamado trigger_names", "actual": apply_kamado.trigger_names, "expected": PackedStringArray(["on_hit"])},
        {"label": "sukuna_apply_kamado effect_definition_id", "actual": String(apply_kamado_payload.effect_definition_id), "expected": "sukuna_kamado_mark"},
        {"label": "sukuna_kamado_mark duration_mode", "actual": String(kamado_mark.duration_mode), "expected": "turns"},
        {"label": "sukuna_kamado_mark duration", "actual": int(kamado_mark.duration), "expected": 3},
        {"label": "sukuna_kamado_mark decrement_on", "actual": String(kamado_mark.decrement_on), "expected": "turn_end"},
        {"label": "sukuna_kamado_mark stacking", "actual": String(kamado_mark.stacking), "expected": "stack"},
        {"label": "sukuna_kamado_mark trigger_names", "actual": kamado_mark.trigger_names, "expected": PackedStringArray(["on_exit"])},
        {"label": "sukuna_kamado_mark on_expire_effect_ids", "actual": kamado_mark.on_expire_effect_ids, "expected": PackedStringArray(["sukuna_kamado_explode"])},
        {"label": "sukuna_kamado_mark persists_on_switch", "actual": bool(kamado_mark.persists_on_switch), "expected": false},
        {"label": "sukuna_kamado payload_type", "actual": String(kamado_payload.payload_type), "expected": "damage"},
        {"label": "sukuna_kamado amount", "actual": int(kamado_payload.amount), "expected": 20},
        {"label": "sukuna_kamado use_formula", "actual": bool(kamado_payload.use_formula), "expected": false},
        {"label": "sukuna_kamado combat_type_id", "actual": String(kamado_payload.combat_type_id), "expected": "fire"},
        {"label": "sukuna_kamado_explode trigger_names", "actual": kamado_explode.trigger_names, "expected": PackedStringArray(["on_expire"])},
        {"label": "sukuna_kamado_explode amount", "actual": int(kamado_expire_payload.amount), "expected": 20},
        {"label": "sukuna_kamado_explode combat_type_id", "actual": String(kamado_expire_payload.combat_type_id), "expected": "fire"},
        {"label": "sukuna_apply_domain_field duration_mode", "actual": String(apply_domain.duration_mode), "expected": "turns"},
        {"label": "sukuna_apply_domain_field duration", "actual": int(apply_domain.duration), "expected": 3},
        {"label": "sukuna_apply_domain_field decrement_on", "actual": String(apply_domain.decrement_on), "expected": "turn_end"},
        {"label": "sukuna_apply_domain_field scope", "actual": String(apply_domain.scope), "expected": "field"},
        {"label": "sukuna_apply_domain_field stacking", "actual": String(apply_domain.stacking), "expected": "replace"},
        {"label": "sukuna_apply_domain_field trigger_names", "actual": apply_domain.trigger_names, "expected": PackedStringArray(["on_hit"])},
        {"label": "sukuna_apply_domain_field field_definition_id", "actual": String(apply_domain_payload.field_definition_id), "expected": "sukuna_malevolent_shrine_field"},
        {"label": "sukuna_malevolent_shrine_field field_kind", "actual": String(domain_field.field_kind), "expected": "domain"},
        {"label": "sukuna_malevolent_shrine_field effect_ids", "actual": domain_field.effect_ids, "expected": PackedStringArray(["sukuna_domain_cast_buff"])},
        {"label": "sukuna_malevolent_shrine_field on_expire_effect_ids", "actual": domain_field.on_expire_effect_ids, "expected": PackedStringArray(["sukuna_domain_buff_remove", "sukuna_domain_expire_burst"])},
        {"label": "sukuna_malevolent_shrine_field on_break_effect_ids", "actual": domain_field.on_break_effect_ids, "expected": PackedStringArray(["sukuna_domain_buff_remove"])},
        {"label": "sukuna_malevolent_shrine_field creator_accuracy_override", "actual": int(domain_field.creator_accuracy_override), "expected": 100},
        {"label": "sukuna_domain_cast_buff trigger_names", "actual": domain_cast_buff.trigger_names, "expected": PackedStringArray(["field_apply"])},
        {"label": "sukuna_domain_cast_buff attack stat_name", "actual": String(domain_attack_payload.stat_name), "expected": "attack"},
        {"label": "sukuna_domain_cast_buff attack stage_delta", "actual": int(domain_attack_payload.stage_delta), "expected": 1},
        {"label": "sukuna_domain_cast_buff sp_attack stat_name", "actual": String(domain_sp_attack_payload.stat_name), "expected": "sp_attack"},
        {"label": "sukuna_domain_cast_buff sp_attack stage_delta", "actual": int(domain_sp_attack_payload.stage_delta), "expected": 1},
        {"label": "sukuna_domain_buff_remove trigger_names", "actual": domain_buff_remove.trigger_names, "expected": PackedStringArray(["field_break", "field_expire"])},
        {"label": "sukuna_domain_buff_remove attack stage_delta", "actual": int(domain_remove_attack_payload.stage_delta), "expected": -1},
        {"label": "sukuna_domain_buff_remove sp_attack stage_delta", "actual": int(domain_remove_sp_attack_payload.stage_delta), "expected": -1},
        {"label": "sukuna_domain_expire_burst trigger_names", "actual": domain_expire_burst.trigger_names, "expected": PackedStringArray(["field_expire"])},
        {"label": "sukuna_domain_expire_burst amount", "actual": int(domain_expire_payload.amount), "expected": 20},
        {"label": "sukuna_domain_expire_burst use_formula", "actual": bool(domain_expire_payload.use_formula), "expected": false},
        {"label": "sukuna_domain_expire_burst combat_type_id", "actual": String(domain_expire_payload.combat_type_id), "expected": "fire"},
        {"label": "sukuna_teach_love trigger_names", "actual": passive_skill.trigger_names, "expected": PackedStringArray(["on_matchup_changed"])},
        {"label": "sukuna_teach_love effect_ids", "actual": passive_skill.effect_ids, "expected": PackedStringArray(["sukuna_refresh_love_regen"])},
        {"label": "sukuna_refresh_love_regen trigger_names", "actual": regen_effect.trigger_names, "expected": PackedStringArray(["on_matchup_changed"])},
        {"label": "sukuna_refresh_love_regen mod_kind", "actual": String(regen_payload.mod_kind), "expected": "mp_regen"},
        {"label": "sukuna_refresh_love_regen mod_op", "actual": String(regen_payload.mod_op), "expected": "add"},
        {"label": "sukuna_refresh_love_regen duration_mode", "actual": String(regen_payload.duration_mode), "expected": "permanent"},
        {"label": "sukuna_refresh_love_regen decrement_on", "actual": String(regen_payload.decrement_on), "expected": "turn_start"},
        {"label": "sukuna_refresh_love_regen stacking", "actual": String(regen_payload.stacking), "expected": "replace"},
        {"label": "sukuna_refresh_love_regen dynamic_value_formula", "actual": String(regen_payload.dynamic_value_formula), "expected": "matchup_bst_gap_band"},
        {"label": "sukuna_refresh_love_regen thresholds", "actual": regen_payload.dynamic_value_thresholds, "expected": PackedInt32Array([20, 40, 70, 110, 160])},
        {"label": "sukuna_refresh_love_regen outputs", "actual": regen_payload.dynamic_value_outputs, "expected": PackedFloat32Array([9.0, 8.0, 7.0, 6.0, 5.0])},
        {"label": "sukuna_refresh_love_regen default", "actual": float(regen_payload.dynamic_value_default), "expected": 0.0},
    ]
    return _helper.run_checks(harness, checks)
