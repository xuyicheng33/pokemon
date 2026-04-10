extends RefCounted
class_name GojoSnapshotSuite

const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const FormalCharacterSnapshotTestHelperScript := preload("res://tests/support/formal_character_snapshot_test_helper.gd")

var _helper = FormalCharacterSnapshotTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("gojo_unit_snapshot_contract", failures, Callable(self, "_test_gojo_unit_snapshot_contract").bind(harness))
    runner.run_test("gojo_skill_snapshot_contract", failures, Callable(self, "_test_gojo_skill_snapshot_contract").bind(harness))
    runner.run_test("gojo_effect_snapshot_contract", failures, Callable(self, "_test_gojo_effect_snapshot_contract").bind(harness))

func _test_gojo_unit_snapshot_contract(harness) -> Dictionary:
    var content_index = _helper.build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Gojo unit snapshot")
    return _helper.run_descriptor_checks(
        harness,
        content_index.units,
        [FormalCharacterBaselinesScript.unit_contract("gojo_satoru")],
        "unit_id",
        "missing gojo unit definition"
    )

func _test_gojo_skill_snapshot_contract(harness) -> Dictionary:
    var content_index = _helper.build_content_index(harness)
    if content_index == null:
        return harness.fail_result("failed to load content snapshot for Gojo skill snapshot")
    return _helper.run_descriptor_checks(
        harness,
        content_index.skills,
        FormalCharacterBaselinesScript.skill_contracts("gojo_satoru"),
        "skill_id",
        "missing gojo snapshot skill resource"
    )

func _test_gojo_effect_snapshot_contract(harness) -> Dictionary:
    var content_index = _helper.build_content_index(harness)
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
    var checks: Array[Dictionary] = []
    _helper.append_effect_checks(checks, ao_mark, FormalCharacterBaselinesScript.effect_contract("gojo_satoru", "gojo_ao_mark"))
    _helper.append_effect_checks(checks, aka_mark, FormalCharacterBaselinesScript.effect_contract("gojo_satoru", "gojo_aka_mark"))
    _helper.append_effect_checks(checks, murasaki_burst, FormalCharacterBaselinesScript.effect_contract("gojo_satoru", "gojo_murasaki_conditional_burst"))
    _helper.append_effect_checks(checks, apply_domain, FormalCharacterBaselinesScript.effect_contract("gojo_satoru", "gojo_apply_domain_field"))
    _helper.append_effect_checks(checks, mugen_effect, FormalCharacterBaselinesScript.effect_contract("gojo_satoru", "gojo_mugen_incoming_accuracy_down"))
    _helper.append_passive_checks(checks, mugen, FormalCharacterBaselinesScript.passive_contract("gojo_satoru", "gojo_mugen"))
    _helper.append_field_checks(checks, domain_field, FormalCharacterBaselinesScript.field_contract("gojo_satoru", "gojo_unlimited_void_field"))
    checks.append_array([
        {"label": "gojo_ao_speed_up stat_name", "actual": String(ao_speed_payload.stat_name), "expected": "speed"},
        {"label": "gojo_ao_speed_up stage_delta", "actual": int(ao_speed_payload.stage_delta), "expected": 1},
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
        {"label": "gojo_apply_domain_field field_definition_id", "actual": String(apply_domain_payload.field_definition_id), "expected": "gojo_unlimited_void_field"},
        {"label": "gojo_apply_domain_field on_success_effect_ids", "actual": apply_domain_payload.on_success_effect_ids, "expected": PackedStringArray(["gojo_domain_action_lock"])},
        {"label": "gojo_domain_action_lock mod_kind", "actual": String(domain_lock_payload.mod_kind), "expected": "action_legality"},
        {"label": "gojo_domain_action_lock mod_op", "actual": String(domain_lock_payload.mod_op), "expected": "deny"},
        {"label": "gojo_domain_action_lock value", "actual": String(domain_lock_payload.value), "expected": "all"},
        {"label": "gojo_domain_action_lock duration_mode", "actual": String(domain_lock_payload.duration_mode), "expected": "turns"},
        {"label": "gojo_domain_action_lock duration", "actual": int(domain_lock_payload.duration), "expected": 1},
        {"label": "gojo_domain_action_lock decrement_on", "actual": String(domain_lock_payload.decrement_on), "expected": "turn_end"},
        {"label": "gojo_domain_action_lock stacking", "actual": String(domain_lock_payload.stacking), "expected": "replace"},
        {"label": "gojo_mugen incoming_accuracy mod_kind", "actual": String(mugen_payload.mod_kind), "expected": "incoming_accuracy"},
        {"label": "gojo_mugen incoming_accuracy mod_op", "actual": String(mugen_payload.mod_op), "expected": "add"},
        {"label": "gojo_mugen incoming_accuracy value", "actual": int(mugen_payload.value), "expected": -10},
        {"label": "gojo_mugen incoming_accuracy scope", "actual": String(mugen_payload.scope), "expected": "self"},
        {"label": "gojo_mugen incoming_accuracy duration_mode", "actual": String(mugen_payload.duration_mode), "expected": "permanent"},
    ])
    return _helper.run_checks(harness, checks)
