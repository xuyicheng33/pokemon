extends "res://test/support/gdunit_suite_bridge.gd"

const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const FormalCharacterSnapshotTestHelperScript := preload("res://tests/support/formal_character_snapshot_test_helper.gd")

var _helper = FormalCharacterSnapshotTestHelperScript.new()

func test_sukuna_snapshot_contract() -> void:
	var result := _test_sukuna_unit_snapshot_contract(_harness)
	if not bool(result.get("ok", false)):
		_assert_legacy_result(result)
		return
	result = _test_sukuna_skill_snapshot_contract(_harness)
	if not bool(result.get("ok", false)):
		_assert_legacy_result(result)
		return
	_assert_legacy_result(_test_sukuna_effect_snapshot_contract(_harness))

func _test_sukuna_unit_snapshot_contract(harness) -> Dictionary:
	var content_index = _helper.build_content_index(harness)
	if content_index == null:
		return harness.fail_result("failed to load content snapshot for Sukuna unit snapshot")
	return _helper.run_descriptor_checks(
		harness,
		content_index.units,
		[FormalCharacterBaselinesScript.unit_contract("sukuna")],
		"unit_id",
		"missing sukuna unit definition"
	)

func _test_sukuna_skill_snapshot_contract(harness) -> Dictionary:
	var content_index = _helper.build_content_index(harness)
	if content_index == null:
		return harness.fail_result("failed to load content snapshot for Sukuna skill snapshot")
	return _helper.run_descriptor_checks(
		harness,
		content_index.skills,
		FormalCharacterBaselinesScript.skill_contracts("sukuna"),
		"skill_id",
		"missing sukuna snapshot skill resource"
	)

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
	var checks: Array[Dictionary] = []
	_helper.append_effect_checks(checks, kamado_mark, FormalCharacterBaselinesScript.effect_contract("sukuna", "sukuna_kamado_mark"))
	_helper.append_effect_checks(checks, apply_domain, FormalCharacterBaselinesScript.effect_contract("sukuna", "sukuna_apply_domain_field"))
	_helper.append_passive_checks(checks, passive_skill, FormalCharacterBaselinesScript.passive_contract("sukuna", "sukuna_teach_love"))
	_helper.append_field_checks(checks, domain_field, FormalCharacterBaselinesScript.field_contract("sukuna", "sukuna_malevolent_shrine_field"))
	checks.append_array([
		{"label": "sukuna_apply_kamado effect_definition_id", "actual": String(apply_kamado_payload.effect_definition_id), "expected": "sukuna_kamado_mark"},
		{"label": "sukuna_kamado payload_type", "actual": String(kamado_payload.payload_type), "expected": "damage"},
		{"label": "sukuna_kamado amount", "actual": int(kamado_payload.amount), "expected": 20},
		{"label": "sukuna_kamado use_formula", "actual": bool(kamado_payload.use_formula), "expected": false},
		{"label": "sukuna_kamado combat_type_id", "actual": String(kamado_payload.combat_type_id), "expected": "fire"},
		{"label": "sukuna_kamado_explode trigger_names", "actual": kamado_explode.trigger_names, "expected": PackedStringArray(["on_expire"])},
		{"label": "sukuna_kamado_explode amount", "actual": int(kamado_expire_payload.amount), "expected": 20},
		{"label": "sukuna_kamado_explode combat_type_id", "actual": String(kamado_expire_payload.combat_type_id), "expected": "fire"},
		{"label": "sukuna_apply_domain_field field_definition_id", "actual": String(apply_domain_payload.field_definition_id), "expected": "sukuna_malevolent_shrine_field"},
		{"label": "sukuna_domain_cast_buff attack stat_name", "actual": String(domain_attack_payload.stat_name), "expected": "attack"},
		{"label": "sukuna_domain_cast_buff attack stage_delta", "actual": int(domain_attack_payload.stage_delta), "expected": 1},
		{"label": "sukuna_domain_cast_buff sp_attack stat_name", "actual": String(domain_sp_attack_payload.stat_name), "expected": "sp_attack"},
		{"label": "sukuna_domain_cast_buff sp_attack stage_delta", "actual": int(domain_sp_attack_payload.stage_delta), "expected": 1},
		{"label": "sukuna_domain_buff_remove attack stage_delta", "actual": int(domain_remove_attack_payload.stage_delta), "expected": -1},
		{"label": "sukuna_domain_buff_remove sp_attack stage_delta", "actual": int(domain_remove_sp_attack_payload.stage_delta), "expected": -1},
		{"label": "sukuna_domain_expire_burst amount", "actual": int(domain_expire_payload.amount), "expected": 20},
		{"label": "sukuna_domain_expire_burst use_formula", "actual": bool(domain_expire_payload.use_formula), "expected": false},
		{"label": "sukuna_domain_expire_burst combat_type_id", "actual": String(domain_expire_payload.combat_type_id), "expected": "fire"},
		{"label": "sukuna_refresh_love_regen mod_kind", "actual": String(regen_payload.mod_kind), "expected": "mp_regen"},
		{"label": "sukuna_refresh_love_regen mod_op", "actual": String(regen_payload.mod_op), "expected": "add"},
		{"label": "sukuna_refresh_love_regen duration_mode", "actual": String(regen_payload.duration_mode), "expected": "permanent"},
		{"label": "sukuna_refresh_love_regen decrement_on", "actual": String(regen_payload.decrement_on), "expected": "turn_start"},
		{"label": "sukuna_refresh_love_regen stacking", "actual": String(regen_payload.stacking), "expected": "replace"},
		{"label": "sukuna_refresh_love_regen dynamic_value_formula", "actual": String(regen_payload.dynamic_value_formula), "expected": "matchup_bst_gap_band"},
		{"label": "sukuna_refresh_love_regen thresholds", "actual": regen_payload.dynamic_value_thresholds, "expected": PackedInt32Array([20, 40, 70, 110, 160])},
		{"label": "sukuna_refresh_love_regen outputs", "actual": regen_payload.dynamic_value_outputs, "expected": PackedFloat32Array([9.0, 8.0, 7.0, 6.0, 5.0])},
		{"label": "sukuna_refresh_love_regen default", "actual": float(regen_payload.dynamic_value_default), "expected": 0.0},
	])
	return _helper.run_checks(harness, checks)
