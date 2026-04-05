extends RefCounted
class_name KashimoSnapshotSuite

const FormalCharacterSnapshotTestHelperScript := preload("res://tests/support/formal_character_snapshot_test_helper.gd")

var _helper = FormalCharacterSnapshotTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("kashimo_unit_snapshot_contract", failures, Callable(self, "_test_kashimo_unit_snapshot_contract").bind(harness))
    runner.run_test("kashimo_skill_snapshot_contract", failures, Callable(self, "_test_kashimo_skill_snapshot_contract").bind(harness))
    runner.run_test("kashimo_effect_snapshot_contract", failures, Callable(self, "_test_kashimo_effect_snapshot_contract").bind(harness))

func _test_kashimo_unit_snapshot_contract(harness) -> Dictionary:
    var content_index = _build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Kashimo unit snapshot")
    var kashimo = content_index.units.get("kashimo_hajime", null)
    if kashimo == null:
        return harness.fail_result("missing kashimo unit definition")
    var checks: Array[Dictionary] = [
        {"label": "kashimo display_name", "actual": String(kashimo.display_name), "expected": "鹿紫云一"},
        {"label": "kashimo base_hp", "actual": int(kashimo.base_hp), "expected": 118},
        {"label": "kashimo base_attack", "actual": int(kashimo.base_attack), "expected": 82},
        {"label": "kashimo base_defense", "actual": int(kashimo.base_defense), "expected": 58},
        {"label": "kashimo base_sp_attack", "actual": int(kashimo.base_sp_attack), "expected": 72},
        {"label": "kashimo base_sp_defense", "actual": int(kashimo.base_sp_defense), "expected": 54},
        {"label": "kashimo base_speed", "actual": int(kashimo.base_speed), "expected": 90},
        {"label": "kashimo max_mp", "actual": int(kashimo.max_mp), "expected": 100},
        {"label": "kashimo init_mp", "actual": int(kashimo.init_mp), "expected": 40},
        {"label": "kashimo regen_per_turn", "actual": int(kashimo.regen_per_turn), "expected": 10},
        {"label": "kashimo ultimate_points_required", "actual": int(kashimo.ultimate_points_required), "expected": 3},
        {"label": "kashimo ultimate_points_cap", "actual": int(kashimo.ultimate_points_cap), "expected": 3},
        {"label": "kashimo ultimate_point_gain_on_regular_skill_cast", "actual": int(kashimo.ultimate_point_gain_on_regular_skill_cast), "expected": 1},
        {"label": "kashimo combat_type_ids", "actual": kashimo.combat_type_ids, "expected": PackedStringArray(["thunder", "fighting"])},
        {"label": "kashimo default skill_ids", "actual": kashimo.skill_ids, "expected": PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_feedback_strike"])},
        {"label": "kashimo candidate_skill_ids", "actual": kashimo.candidate_skill_ids, "expected": PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_feedback_strike", "kashimo_kyokyo_katsura"])},
        {"label": "kashimo ultimate_skill_id", "actual": String(kashimo.ultimate_skill_id), "expected": "kashimo_phantom_beast_amber"},
        {"label": "kashimo passive_skill_id", "actual": String(kashimo.passive_skill_id), "expected": "kashimo_charge_separation"},
    ]
    return _run_checks(harness, checks)

func _test_kashimo_skill_snapshot_contract(harness) -> Dictionary:
    var content_index = _build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Kashimo skill snapshot")
    var raiken = content_index.skills.get("kashimo_raiken", null)
    var charge = content_index.skills.get("kashimo_charge", null)
    var feedback = content_index.skills.get("kashimo_feedback_strike", null)
    var kyokyo = content_index.skills.get("kashimo_kyokyo_katsura", null)
    var amber = content_index.skills.get("kashimo_phantom_beast_amber", null)
    if raiken == null or charge == null or feedback == null or kyokyo == null or amber == null:
        return harness.fail_result("missing kashimo snapshot skill resource")
    var checks: Array[Dictionary] = [
        {"label": "kashimo_raiken damage_kind", "actual": String(raiken.damage_kind), "expected": "physical"},
        {"label": "kashimo_raiken power", "actual": int(raiken.power), "expected": 45},
        {"label": "kashimo_raiken accuracy", "actual": int(raiken.accuracy), "expected": 100},
        {"label": "kashimo_raiken mp_cost", "actual": int(raiken.mp_cost), "expected": 12},
        {"label": "kashimo_raiken priority", "actual": int(raiken.priority), "expected": 1},
        {"label": "kashimo_raiken combat_type_id", "actual": String(raiken.combat_type_id), "expected": "thunder"},
        {"label": "kashimo_raiken effects_on_hit_ids", "actual": raiken.effects_on_hit_ids, "expected": PackedStringArray(["kashimo_apply_negative_charge"])},
        {"label": "kashimo_charge damage_kind", "actual": String(charge.damage_kind), "expected": "none"},
        {"label": "kashimo_charge power", "actual": int(charge.power), "expected": 0},
        {"label": "kashimo_charge accuracy", "actual": int(charge.accuracy), "expected": 100},
        {"label": "kashimo_charge mp_cost", "actual": int(charge.mp_cost), "expected": 8},
        {"label": "kashimo_charge priority", "actual": int(charge.priority), "expected": 0},
        {"label": "kashimo_charge targeting", "actual": String(charge.targeting), "expected": "self"},
        {"label": "kashimo_charge effects_on_cast_ids", "actual": charge.effects_on_cast_ids, "expected": PackedStringArray(["kashimo_apply_positive_charge"])},
        {"label": "kashimo_feedback damage_kind", "actual": String(feedback.damage_kind), "expected": "special"},
        {"label": "kashimo_feedback power", "actual": int(feedback.power), "expected": 30},
        {"label": "kashimo_feedback accuracy", "actual": int(feedback.accuracy), "expected": 100},
        {"label": "kashimo_feedback mp_cost", "actual": int(feedback.mp_cost), "expected": 15},
        {"label": "kashimo_feedback combat_type_id", "actual": String(feedback.combat_type_id), "expected": "thunder"},
        {"label": "kashimo_feedback power_bonus_source", "actual": String(feedback.power_bonus_source), "expected": "effect_stack_sum"},
        {"label": "kashimo_feedback self effect ids", "actual": feedback.power_bonus_self_effect_ids, "expected": PackedStringArray(["kashimo_positive_charge_mark"])},
        {"label": "kashimo_feedback target effect ids", "actual": feedback.power_bonus_target_effect_ids, "expected": PackedStringArray(["kashimo_negative_charge_mark"])},
        {"label": "kashimo_feedback per stack", "actual": int(feedback.power_bonus_per_stack), "expected": 12},
        {"label": "kashimo_feedback effects_on_hit_ids", "actual": feedback.effects_on_hit_ids, "expected": PackedStringArray(["kashimo_consume_positive_charges", "kashimo_consume_negative_charges"])},
        {"label": "kashimo_kyokyo damage_kind", "actual": String(kyokyo.damage_kind), "expected": "none"},
        {"label": "kashimo_kyokyo power", "actual": int(kyokyo.power), "expected": 0},
        {"label": "kashimo_kyokyo accuracy", "actual": int(kyokyo.accuracy), "expected": 100},
        {"label": "kashimo_kyokyo mp_cost", "actual": int(kyokyo.mp_cost), "expected": 20},
        {"label": "kashimo_kyokyo priority", "actual": int(kyokyo.priority), "expected": 2},
        {"label": "kashimo_kyokyo effects_on_cast_ids", "actual": kyokyo.effects_on_cast_ids, "expected": PackedStringArray(["kashimo_kyokyo_nullify"])},
        {"label": "kashimo_amber damage_kind", "actual": String(amber.damage_kind), "expected": "special"},
        {"label": "kashimo_amber power", "actual": int(amber.power), "expected": 60},
        {"label": "kashimo_amber accuracy", "actual": int(amber.accuracy), "expected": 100},
        {"label": "kashimo_amber mp_cost", "actual": int(amber.mp_cost), "expected": 35},
        {"label": "kashimo_amber priority", "actual": int(amber.priority), "expected": 5},
        {"label": "kashimo_amber combat_type_id", "actual": String(amber.combat_type_id), "expected": "thunder"},
        {"label": "kashimo_amber effects_on_cast_ids", "actual": amber.effects_on_cast_ids, "expected": PackedStringArray(["kashimo_amber_self_transform"])},
    ]
    return _run_checks(harness, checks)

func _test_kashimo_effect_snapshot_contract(harness) -> Dictionary:
    var content_index = _build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Kashimo effect snapshot")
    var negative_mark = content_index.effects.get("kashimo_negative_charge_mark", null)
    var positive_mark = content_index.effects.get("kashimo_positive_charge_mark", null)
    var consume_positive = content_index.effects.get("kashimo_consume_positive_charges", null)
    var consume_negative = content_index.effects.get("kashimo_consume_negative_charges", null)
    var kyokyo = content_index.effects.get("kashimo_kyokyo_nullify", null)
    var thunder_resist = content_index.effects.get("kashimo_thunder_resist", null)
    var apply_water = content_index.effects.get("kashimo_apply_water_leak_listeners", null)
    var water_self = content_index.effects.get("kashimo_water_leak_self_listener", null)
    var water_counter = content_index.effects.get("kashimo_water_leak_counter_listener", null)
    var amber_transform = content_index.effects.get("kashimo_amber_self_transform", null)
    var amber_bleed = content_index.effects.get("kashimo_amber_bleed", null)
    var passive = content_index.passive_skills.get("kashimo_charge_separation", null)
    if negative_mark == null or positive_mark == null or consume_positive == null or consume_negative == null or kyokyo == null or thunder_resist == null or apply_water == null or water_self == null or water_counter == null or amber_transform == null or amber_bleed == null or passive == null:
        return harness.fail_result("missing kashimo snapshot effect resource")
    var negative_payload = negative_mark.payloads[0]
    var positive_payload = positive_mark.payloads[0]
    var consume_positive_payload = consume_positive.payloads[0]
    var consume_negative_payload = consume_negative.payloads[0]
    var kyokyo_payload = kyokyo.payloads[0]
    var thunder_payload = thunder_resist.payloads[0]
    var apply_water_self_payload = apply_water.payloads[0]
    var apply_water_counter_payload = apply_water.payloads[1]
    var water_self_payload = water_self.payloads[0]
    var water_counter_payload = water_counter.payloads[0]
    var amber_attack_payload = amber_transform.payloads[0]
    var amber_sp_attack_payload = amber_transform.payloads[1]
    var amber_speed_payload = amber_transform.payloads[2]
    var amber_bleed_apply_payload = amber_transform.payloads[3]
    var amber_ult_lock_payload = amber_transform.payloads[4]
    var amber_bleed_payload = amber_bleed.payloads[0]
    var checks: Array[Dictionary] = [
        {"label": "kashimo_negative_mark duration_mode", "actual": String(negative_mark.duration_mode), "expected": "turns"},
        {"label": "kashimo_negative_mark duration", "actual": int(negative_mark.duration), "expected": 4},
        {"label": "kashimo_negative_mark decrement_on", "actual": String(negative_mark.decrement_on), "expected": "turn_end"},
        {"label": "kashimo_negative_mark stacking", "actual": String(negative_mark.stacking), "expected": "stack"},
        {"label": "kashimo_negative_mark max_stacks", "actual": int(negative_mark.max_stacks), "expected": 3},
        {"label": "kashimo_negative_mark amount", "actual": int(negative_payload.amount), "expected": 8},
        {"label": "kashimo_negative_mark combat_type_id", "actual": String(negative_payload.combat_type_id), "expected": "thunder"},
        {"label": "kashimo_positive_mark duration_mode", "actual": String(positive_mark.duration_mode), "expected": "turns"},
        {"label": "kashimo_positive_mark duration", "actual": int(positive_mark.duration), "expected": 4},
        {"label": "kashimo_positive_mark decrement_on", "actual": String(positive_mark.decrement_on), "expected": "turn_end"},
        {"label": "kashimo_positive_mark stacking", "actual": String(positive_mark.stacking), "expected": "stack"},
        {"label": "kashimo_positive_mark max_stacks", "actual": int(positive_mark.max_stacks), "expected": 3},
        {"label": "kashimo_positive_mark amount", "actual": int(positive_payload.amount), "expected": 5},
        {"label": "kashimo_positive_mark resource_key", "actual": String(positive_payload.resource_key), "expected": "mp"},
        {"label": "kashimo_consume_positive remove_mode", "actual": String(consume_positive_payload.remove_mode), "expected": "all"},
        {"label": "kashimo_consume_positive effect_definition_id", "actual": String(consume_positive_payload.effect_definition_id), "expected": "kashimo_positive_charge_mark"},
        {"label": "kashimo_consume_negative remove_mode", "actual": String(consume_negative_payload.remove_mode), "expected": "all"},
        {"label": "kashimo_consume_negative effect_definition_id", "actual": String(consume_negative_payload.effect_definition_id), "expected": "kashimo_negative_charge_mark"},
        {"label": "kashimo_kyokyo effect.duration_mode", "actual": String(kyokyo.duration_mode), "expected": "turns"},
        {"label": "kashimo_kyokyo effect.duration", "actual": int(kyokyo.duration), "expected": 3},
        {"label": "kashimo_kyokyo effect.decrement_on", "actual": String(kyokyo.decrement_on), "expected": "turn_end"},
        {"label": "kashimo_kyokyo mod_kind", "actual": String(kyokyo_payload.mod_kind), "expected": "nullify_field_accuracy"},
        {"label": "kashimo_kyokyo duration", "actual": int(kyokyo_payload.duration), "expected": 3},
        {"label": "kashimo_kyokyo decrement_on", "actual": String(kyokyo_payload.decrement_on), "expected": "turn_end"},
        {"label": "kashimo_thunder_resist mod_kind", "actual": String(thunder_payload.mod_kind), "expected": "incoming_action_final_mod"},
        {"label": "kashimo_thunder_resist mod_op", "actual": String(thunder_payload.mod_op), "expected": "mul"},
        {"label": "kashimo_thunder_resist value", "actual": float(thunder_payload.value), "expected": 0.5},
        {"label": "kashimo_thunder_resist command_filters", "actual": thunder_payload.required_incoming_command_types, "expected": PackedStringArray(["skill", "ultimate"])},
        {"label": "kashimo_thunder_resist combat_filters", "actual": thunder_payload.required_incoming_combat_type_ids, "expected": PackedStringArray(["thunder"])},
        {"label": "kashimo_charge_separation trigger_names", "actual": passive.trigger_names, "expected": PackedStringArray(["on_enter"])},
        {"label": "kashimo_charge_separation effect_ids", "actual": passive.effect_ids, "expected": PackedStringArray(["kashimo_thunder_resist", "kashimo_apply_water_leak_listeners"])},
        {"label": "kashimo_apply_water_self effect_definition_id", "actual": String(apply_water_self_payload.effect_definition_id), "expected": "kashimo_water_leak_self_listener"},
        {"label": "kashimo_apply_water_counter effect_definition_id", "actual": String(apply_water_counter_payload.effect_definition_id), "expected": "kashimo_water_leak_counter_listener"},
        {"label": "kashimo_water_self scope", "actual": String(water_self.scope), "expected": "self"},
        {"label": "kashimo_water_self trigger_names", "actual": water_self.trigger_names, "expected": PackedStringArray(["on_receive_action_hit"])},
        {"label": "kashimo_water_self command_filters", "actual": water_self.required_incoming_command_types, "expected": PackedStringArray(["skill", "ultimate"])},
        {"label": "kashimo_water_self combat_filters", "actual": water_self.required_incoming_combat_type_ids, "expected": PackedStringArray(["water"])},
        {"label": "kashimo_water_self payload amount", "actual": int(water_self_payload.amount), "expected": -15},
        {"label": "kashimo_water_counter scope", "actual": String(water_counter.scope), "expected": "action_actor"},
        {"label": "kashimo_water_counter trigger_names", "actual": water_counter.trigger_names, "expected": PackedStringArray(["on_receive_action_hit"])},
        {"label": "kashimo_water_counter command_filters", "actual": water_counter.required_incoming_command_types, "expected": PackedStringArray(["skill", "ultimate"])},
        {"label": "kashimo_water_counter combat_filters", "actual": water_counter.required_incoming_combat_type_ids, "expected": PackedStringArray(["water"])},
        {"label": "kashimo_water_counter payload amount", "actual": int(water_counter_payload.amount), "expected": 15},
        {"label": "kashimo_water_counter payload type", "actual": String(water_counter_payload.combat_type_id), "expected": "poison"},
        {"label": "kashimo_amber_attack stat_name", "actual": String(amber_attack_payload.stat_name), "expected": "attack"},
        {"label": "kashimo_amber_attack stage_delta", "actual": int(amber_attack_payload.stage_delta), "expected": 2},
        {"label": "kashimo_amber_attack retention_mode", "actual": String(amber_attack_payload.retention_mode), "expected": "persist_on_switch"},
        {"label": "kashimo_amber_sp_attack stat_name", "actual": String(amber_sp_attack_payload.stat_name), "expected": "sp_attack"},
        {"label": "kashimo_amber_sp_attack stage_delta", "actual": int(amber_sp_attack_payload.stage_delta), "expected": 2},
        {"label": "kashimo_amber_speed stat_name", "actual": String(amber_speed_payload.stat_name), "expected": "speed"},
        {"label": "kashimo_amber_speed stage_delta", "actual": int(amber_speed_payload.stage_delta), "expected": 1},
        {"label": "kashimo_amber_bleed apply_effect", "actual": String(amber_bleed_apply_payload.effect_definition_id), "expected": "kashimo_amber_bleed"},
        {"label": "kashimo_amber_ult_lock mod_kind", "actual": String(amber_ult_lock_payload.mod_kind), "expected": "action_legality"},
        {"label": "kashimo_amber_ult_lock mod_op", "actual": String(amber_ult_lock_payload.mod_op), "expected": "deny"},
        {"label": "kashimo_amber_ult_lock value", "actual": String(amber_ult_lock_payload.value), "expected": "ultimate"},
        {"label": "kashimo_amber_ult_lock persists_on_switch", "actual": bool(amber_ult_lock_payload.persists_on_switch), "expected": true},
        {"label": "kashimo_amber_bleed trigger_names", "actual": amber_bleed.trigger_names, "expected": PackedStringArray(["turn_end"])},
        {"label": "kashimo_amber_bleed persists_on_switch", "actual": bool(amber_bleed.persists_on_switch), "expected": true},
        {"label": "kashimo_amber_bleed amount", "actual": int(amber_bleed_payload.amount), "expected": 20},
    ]
    return _run_checks(harness, checks)

func _build_content_index(harness):
    return _helper.build_content_index(harness)

func _run_checks(harness, checks: Array[Dictionary]) -> Dictionary:
    return _helper.run_checks(harness, checks)
