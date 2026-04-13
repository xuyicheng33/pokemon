extends "res://test/support/gdunit_suite_bridge.gd"

const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")
const FormalCharacterSnapshotTestHelperScript := preload("res://tests/support/formal_character_snapshot_test_helper.gd")

var _support = ObitoTestSupportScript.new()
var _helper = FormalCharacterSnapshotTestHelperScript.new()



func test_obito_unit_snapshot_contract() -> void:
	_assert_legacy_result(_test_obito_unit_snapshot_contract(_harness))

func test_obito_skill_snapshot_contract() -> void:
	_assert_legacy_result(_test_obito_skill_snapshot_contract(_harness))

func test_obito_effect_snapshot_contract() -> void:
	_assert_legacy_result(_test_obito_effect_snapshot_contract(_harness))

func test_obito_candidate_loadout_contract() -> void:
	_assert_legacy_result(_test_obito_candidate_loadout_contract(_harness))
func _test_obito_unit_snapshot_contract(harness) -> Dictionary:
	var content_index = _helper.build_content_index(harness)
	if content_index == null:
		return harness.fail_result("failed to load content snapshot for Obito unit snapshot")
	return _helper.run_descriptor_checks(
		harness,
		content_index.units,
		[FormalCharacterBaselinesScript.unit_contract("obito_juubi_jinchuriki")],
		"unit_id",
		"missing obito unit definition"
	)

func _test_obito_skill_snapshot_contract(harness) -> Dictionary:
	var content_index = _helper.build_content_index(harness)
	if content_index == null:
		return harness.fail_result("failed to load content snapshot for Obito skill snapshot")
	var contract_result = _helper.run_descriptor_checks(
		harness,
		content_index.skills,
		FormalCharacterBaselinesScript.skill_contracts("obito_juubi_jinchuriki"),
		"skill_id",
		"missing obito snapshot skill resource"
	)
	if not bool(contract_result.get("ok", false)):
		return contract_result
	var ultimate = content_index.skills.get("obito_shiwei_weishouyu", null)
	if ultimate == null:
		return harness.fail_result("missing obito snapshot skill resource")
	return _helper.run_checks(harness, [
		{"label": "obito_shiwei_weishouyu segment_count", "actual": int(ultimate.damage_segments.size()), "expected": 2},
	])

func _test_obito_effect_snapshot_contract(harness) -> Dictionary:
	var content_index = _helper.build_content_index(harness)
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
	var checks: Array[Dictionary] = []
	_helper.append_passive_checks(checks, passive, FormalCharacterBaselinesScript.passive_contract("obito_juubi_jinchuriki", "obito_xianren_zhili"))
	_helper.append_effect_checks(checks, heal, FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_xianren_zhili_heal"))
	_helper.append_effect_checks(checks, yinyang, FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_zhili"))
	_helper.append_effect_checks(checks, mark_apply, FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_jiaotu_heal_block_apply"))
	_helper.append_effect_checks(checks, mark, FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_jiaotu_heal_block_mark"))
	_helper.append_effect_checks(checks, rule_mod, FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_jiaotu_heal_block_rule_mod"))
	_helper.append_effect_checks(checks, guard, FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_dun_guard_rule_mod"))
	_helper.append_effect_checks(checks, listener_apply, FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_dun_guard_stack_listener"))
	_helper.append_effect_checks(checks, listener_state, FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_dun_guard_stack_listener_state"))
	_helper.append_effect_checks(checks, clear, FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_yu_clear_yinyang"))
	checks.append_array([
		{"label": "obito_xianren_zhili_heal percent", "actual": int(heal_payload.percent), "expected": 10},
		{"label": "obito_xianren_zhili_heal percent_base", "actual": String(heal_payload.percent_base), "expected": "missing_hp"},
		{"label": "obito_qiudao_jiaotu_mark_apply target", "actual": String(mark_apply_payload.effect_definition_id), "expected": "obito_qiudao_jiaotu_heal_block_mark"},
		{"label": "obito_qiudao_jiaotu_rule_mod kind", "actual": String(rule_mod_payload.mod_kind), "expected": "incoming_heal_final_mod"},
		{"label": "obito_qiudao_jiaotu_rule_mod op", "actual": String(rule_mod_payload.mod_op), "expected": "set"},
		{"label": "obito_qiudao_jiaotu_rule_mod value", "actual": float(rule_mod_payload.value), "expected": 0.0},
		{"label": "obito_qiudao_jiaotu_rule_mod scope", "actual": String(rule_mod_payload.scope), "expected": "target"},
		{"label": "obito_yinyang_boost target", "actual": String(boost_apply_payload.effect_definition_id), "expected": "obito_yinyang_zhili"},
		{"label": "obito_yinyang_boost def", "actual": String(boost_def_payload.stat_name), "expected": "defense"},
		{"label": "obito_yinyang_boost def stage", "actual": int(boost_def_payload.stage_delta), "expected": 1},
		{"label": "obito_yinyang_boost sp_def", "actual": String(boost_sp_def_payload.stat_name), "expected": "sp_defense"},
		{"label": "obito_yinyang_boost sp_def stage", "actual": int(boost_sp_def_payload.stage_delta), "expected": 1},
		{"label": "obito_yinyang_guard mod_kind", "actual": String(guard_payload.mod_kind), "expected": "incoming_action_final_mod"},
		{"label": "obito_yinyang_guard mod_op", "actual": String(guard_payload.mod_op), "expected": "mul"},
		{"label": "obito_yinyang_guard value", "actual": float(guard_payload.value), "expected": 0.5},
		{"label": "obito_yinyang_guard command_filters", "actual": guard_payload.required_incoming_command_types, "expected": PackedStringArray(["skill", "ultimate"])},
		{"label": "obito_yinyang_listener_apply target", "actual": String(listener_apply_payload.effect_definition_id), "expected": "obito_yinyang_dun_guard_stack_listener_state"},
		{"label": "obito_yinyang_listener_state apply target", "actual": String(listener_state_payload.effect_definition_id), "expected": "obito_yinyang_zhili"},
		{"label": "obito_qiudao_yu_clear effect_definition_id", "actual": String(clear_payload.effect_definition_id), "expected": "obito_yinyang_zhili"},
		{"label": "obito_qiudao_yu_clear remove_mode", "actual": String(clear_payload.remove_mode), "expected": "all"},
	])
	return _helper.run_checks(harness, checks)

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
