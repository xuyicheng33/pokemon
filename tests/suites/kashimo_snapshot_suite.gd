extends RefCounted
class_name KashimoSnapshotSuite

const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const FormalCharacterSnapshotTestHelperScript := preload("res://tests/support/formal_character_snapshot_test_helper.gd")

var _helper = FormalCharacterSnapshotTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("kashimo_unit_snapshot_contract", failures, Callable(self, "_test_kashimo_unit_snapshot_contract").bind(harness))
    runner.run_test("kashimo_skill_snapshot_contract", failures, Callable(self, "_test_kashimo_skill_snapshot_contract").bind(harness))
    runner.run_test("kashimo_effect_snapshot_contract", failures, Callable(self, "_test_kashimo_effect_snapshot_contract").bind(harness))

func _test_kashimo_unit_snapshot_contract(harness) -> Dictionary:
    var content_index = _helper.build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Kashimo unit snapshot")
    return _helper.run_descriptor_checks(
        harness,
        content_index.units,
        [FormalCharacterBaselinesScript.unit_contract("kashimo")],
        "unit_id",
        "missing kashimo unit definition"
    )

func _test_kashimo_skill_snapshot_contract(harness) -> Dictionary:
    var content_index = _helper.build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Kashimo skill snapshot")
    return _helper.run_descriptor_checks(
        harness,
        content_index.skills,
        FormalCharacterBaselinesScript.skill_contracts("kashimo"),
        "skill_id",
        "missing kashimo snapshot skill resource"
    )

func _test_kashimo_effect_snapshot_contract(harness) -> Dictionary:
    var content_index = _helper.build_content_index(harness)
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
    var checks: Array[Dictionary] = []
    _helper.append_effect_checks(checks, negative_mark, FormalCharacterBaselinesScript.effect_contract("kashimo", "kashimo_negative_charge_mark"))
    _helper.append_effect_checks(checks, positive_mark, FormalCharacterBaselinesScript.effect_contract("kashimo", "kashimo_positive_charge_mark"))
    _helper.append_effect_checks(checks, kyokyo, FormalCharacterBaselinesScript.effect_contract("kashimo", "kashimo_kyokyo_nullify"))
    _helper.append_effect_checks(checks, water_self, FormalCharacterBaselinesScript.effect_contract("kashimo", "kashimo_water_leak_self_listener"))
    _helper.append_effect_checks(checks, water_counter, FormalCharacterBaselinesScript.effect_contract("kashimo", "kashimo_water_leak_counter_listener"))
    _helper.append_effect_checks(checks, amber_bleed, FormalCharacterBaselinesScript.effect_contract("kashimo", "kashimo_amber_bleed"))
    _helper.append_passive_checks(checks, passive, FormalCharacterBaselinesScript.passive_contract("kashimo", "kashimo_charge_separation"))
    checks.append_array([
        {"label": "kashimo_negative_mark amount", "actual": int(negative_payload.amount), "expected": 8},
        {"label": "kashimo_negative_mark combat_type_id", "actual": String(negative_payload.combat_type_id), "expected": "thunder"},
        {"label": "kashimo_positive_mark amount", "actual": int(positive_payload.amount), "expected": 5},
        {"label": "kashimo_positive_mark resource_key", "actual": String(positive_payload.resource_key), "expected": "mp"},
        {"label": "kashimo_consume_positive remove_mode", "actual": String(consume_positive_payload.remove_mode), "expected": "all"},
        {"label": "kashimo_consume_positive effect_definition_id", "actual": String(consume_positive_payload.effect_definition_id), "expected": "kashimo_positive_charge_mark"},
        {"label": "kashimo_consume_negative remove_mode", "actual": String(consume_negative_payload.remove_mode), "expected": "all"},
        {"label": "kashimo_consume_negative effect_definition_id", "actual": String(consume_negative_payload.effect_definition_id), "expected": "kashimo_negative_charge_mark"},
        {"label": "kashimo_kyokyo mod_kind", "actual": String(kyokyo_payload.mod_kind), "expected": "nullify_field_accuracy"},
        {"label": "kashimo_kyokyo duration", "actual": int(kyokyo_payload.duration), "expected": 3},
        {"label": "kashimo_kyokyo decrement_on", "actual": String(kyokyo_payload.decrement_on), "expected": "turn_end"},
        {"label": "kashimo_thunder_resist mod_kind", "actual": String(thunder_payload.mod_kind), "expected": "incoming_action_final_mod"},
        {"label": "kashimo_thunder_resist mod_op", "actual": String(thunder_payload.mod_op), "expected": "mul"},
        {"label": "kashimo_thunder_resist value", "actual": float(thunder_payload.value), "expected": 0.5},
        {"label": "kashimo_thunder_resist command_filters", "actual": thunder_payload.required_incoming_command_types, "expected": PackedStringArray(["skill", "ultimate"])},
        {"label": "kashimo_thunder_resist combat_filters", "actual": thunder_payload.required_incoming_combat_type_ids, "expected": PackedStringArray(["thunder"])},
        {"label": "kashimo_apply_water_self effect_definition_id", "actual": String(apply_water_self_payload.effect_definition_id), "expected": "kashimo_water_leak_self_listener"},
        {"label": "kashimo_apply_water_counter effect_definition_id", "actual": String(apply_water_counter_payload.effect_definition_id), "expected": "kashimo_water_leak_counter_listener"},
        {"label": "kashimo_water_self payload amount", "actual": int(water_self_payload.amount), "expected": -15},
        {"label": "kashimo_water_counter payload amount", "actual": int(water_counter_payload.amount), "expected": 15},
        {"label": "kashimo_water_counter use_formula", "actual": bool(water_counter_payload.use_formula), "expected": false},
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
        {"label": "kashimo_amber_bleed amount", "actual": int(amber_bleed_payload.amount), "expected": 20},
    ])
    return _helper.run_checks(harness, checks)
