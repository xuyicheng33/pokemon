extends RefCounted
class_name FormalCharacterPairSmokeInteractionSuite

const SharedScript := preload("res://tests/suites/formal_character_pair_smoke/shared.gd")
const FormalCharacterTestSupportScript := preload("res://tests/support/formal_character_test_support.gd")
const GojoUnlimitedVoidSuiteScript := preload("res://tests/suites/gojo_unlimited_void_suite.gd")
const KashimoSetupLoadoutSuiteScript := preload("res://tests/suites/kashimo_setup_loadout_suite.gd")
const ObitoRuntimePassiveAndSealSuiteScript := preload("res://tests/suites/obito_runtime_passive_and_seal_suite.gd")
const ObitoRuntimeYinyangSuiteScript := preload("res://tests/suites/obito_runtime_yinyang_suite.gd")
const SukunaTestSupportScript := preload("res://tests/support/sukuna_test_support.gd")

const EXPECTED_SCENARIO_IDS = [
	"gojo_vs_sukuna_domain_cleanup",
	"gojo_vs_kashimo_kyokyo_nullify_domain_accuracy",
	"gojo_vs_obito_heal_block_public_contract",
	"sukuna_vs_kashimo_domain_accuracy_nullified",
	"sukuna_vs_obito_field_seal_and_kamado_lifecycle",
	"kashimo_vs_obito_yinyang_and_amber_persistence",
]

var _shared = SharedScript.new()
var _support = FormalCharacterTestSupportScript.new()
var _sukuna_support = SukunaTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		runner.run_test("formal_pair_interaction_sample_factory_contract", failures, Callable(self, "_test_sample_factory_contract").bind(harness))
		return
	var interaction_cases: Array = sample_factory.formal_pair_interaction_cases()
	runner.run_test(
		"formal_pair_interaction_case_catalog_contract",
		failures,
		Callable(self, "_test_catalog_contract").bind(harness, interaction_cases)
	)
	for raw_case_spec in interaction_cases:
		if not (raw_case_spec is Dictionary):
			continue
		var case_spec: Dictionary = raw_case_spec
		var test_name := String(case_spec.get("test_name", "")).strip_edges()
		if test_name.is_empty():
			continue
		runner.run_test(test_name, failures, Callable(self, "_test_named_interaction_case").bind(harness, interaction_cases, test_name))

func _test_sample_factory_contract(harness) -> Dictionary:
	return harness.fail_result("SampleBattleFactory init failed")

func _test_catalog_contract(harness, interaction_cases: Array) -> Dictionary:
	var actual_scenarios: Dictionary = {}
	for raw_case_spec in interaction_cases:
		if not (raw_case_spec is Dictionary):
			return harness.fail_result("formal pair interaction case must be Dictionary")
		var case_spec: Dictionary = raw_case_spec
		var scenario_id := String(case_spec.get("scenario_id", "")).strip_edges()
		if scenario_id.is_empty():
			return harness.fail_result("formal pair interaction case missing scenario_id")
		if actual_scenarios.has(scenario_id):
			return harness.fail_result("formal pair interaction duplicated scenario_id: %s" % scenario_id)
		actual_scenarios[scenario_id] = true
	var missing: Array[String] = []
	for scenario_id in EXPECTED_SCENARIO_IDS:
		if not actual_scenarios.has(String(scenario_id)):
			missing.append(String(scenario_id))
	missing.sort()
	if not missing.is_empty():
		return harness.fail_result("formal pair interaction catalog missing required scenarios: %s" % ", ".join(missing))
	var extra: Array[String] = []
	for scenario_id in actual_scenarios.keys():
		if not EXPECTED_SCENARIO_IDS.has(String(scenario_id)):
			extra.append(String(scenario_id))
	extra.sort()
	if not extra.is_empty():
		return harness.fail_result("formal pair interaction catalog contains unknown scenarios: %s" % ", ".join(extra))
	return harness.pass_result()

func _test_named_interaction_case(harness, interaction_cases: Array, test_name: String) -> Dictionary:
	var case_spec := _shared.find_case_by_test_name(interaction_cases, test_name)
	if case_spec.is_empty():
		return harness.fail_result("formal pair interaction missing case_spec for %s" % test_name)
	var scenario_id := String(case_spec.get("scenario_id", "")).strip_edges()
	match scenario_id:
		"gojo_vs_sukuna_domain_cleanup":
			return _test_gojo_vs_sukuna_domain_cleanup(harness)
		"gojo_vs_kashimo_kyokyo_nullify_domain_accuracy":
			return _test_gojo_vs_kashimo_interaction(harness)
		"gojo_vs_obito_heal_block_public_contract":
			return _test_gojo_vs_obito_interaction(harness)
		"sukuna_vs_kashimo_domain_accuracy_nullified":
			return _test_sukuna_vs_kashimo_interaction(harness, case_spec)
		"sukuna_vs_obito_field_seal_and_kamado_lifecycle":
			return _test_sukuna_vs_obito_interaction(harness, case_spec)
		"kashimo_vs_obito_yinyang_and_amber_persistence":
			return _test_kashimo_vs_obito_interaction(harness, case_spec)
		_:
			return harness.fail_result("formal pair interaction unknown scenario_id: %s" % scenario_id)

func _test_gojo_vs_sukuna_domain_cleanup(harness) -> Dictionary:
	var suite := GojoUnlimitedVoidSuiteScript.new()
	return _run_contracts(harness, [
		func() -> Dictionary: return suite._test_gojo_unlimited_void_failed_clash_does_not_revive_action_lock_contract(harness),
		func() -> Dictionary: return suite._test_gojo_unlimited_void_expire_removes_field_buff_contract(harness),
		func() -> Dictionary: return suite._test_gojo_unlimited_void_break_removes_field_buff_contract(harness),
	])

func _test_gojo_vs_kashimo_interaction(harness) -> Dictionary:
	return KashimoSetupLoadoutSuiteScript.new()._test_kashimo_kyokyo_vs_gojo_unlimited_void_contract(harness)

func _test_gojo_vs_obito_interaction(harness) -> Dictionary:
	var passive_suite := ObitoRuntimePassiveAndSealSuiteScript.new()
	return _run_contracts(harness, [
		func() -> Dictionary: return passive_suite._test_obito_qiudao_jiaotu_heal_block_contract(harness),
		func() -> Dictionary: return passive_suite._test_obito_qiudao_jiaotu_switch_persist_contract(harness),
		func() -> Dictionary: return passive_suite._test_obito_qiudao_jiaotu_expire_sync_contract(harness),
	])

func _test_sukuna_vs_kashimo_interaction(harness, case_spec: Dictionary) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var loadout_override := {"P1": {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])}}
	var setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(String(case_spec.get("matchup_id", "")), loadout_override)
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("failed to build sukuna vs kashimo interaction setup: %s" % String(setup_result.get("error_message", "unknown error")))
	var battle_setup = setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	content_index.skills["sukuna_hiraku"].accuracy = 0
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, int(case_spec.get("battle_seed", 0)), battle_setup)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var sukuna = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or sukuna == null:
		return harness.fail_result("missing active units for sukuna vs kashimo interaction")
	sukuna.current_mp = sukuna.max_mp
	sukuna.ultimate_points = sukuna.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi"),
	])
	if battle_state.field_state == null or String(battle_state.field_state.field_def_id) != "sukuna_malevolent_shrine_field":
		return harness.fail_result("sukuna domain should be active before kyokyo interaction turn")
	var hp_before := int(kashimo.current_hp)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 2, "P1", "P1-A", "kashimo_kyokyo_katsura"),
		_support.build_manual_skill_command(core, 2, "P2", "P2-A", "sukuna_hiraku"),
	])
	if int(kashimo.current_hp) != hp_before:
		return harness.fail_result("kyokyo should nullify sukuna domain creator_accuracy_override and restore the zero-accuracy miss")
	var nullify_mod = _support.find_rule_mod_instance(kashimo, "nullify_field_accuracy")
	if nullify_mod == null or int(nullify_mod.remaining) != 2:
		return harness.fail_result("kyokyo should leave nullify_field_accuracy at remaining=2 after the cast turn ends")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 3, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 3, "P2", "P2-A"),
	])
	nullify_mod = _support.find_rule_mod_instance(kashimo, "nullify_field_accuracy")
	if nullify_mod == null or int(nullify_mod.remaining) != 1:
		return harness.fail_result("kyokyo duration should tick down cleanly while sukuna domain stays active")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 4, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 4, "P2", "P2-A"),
	])
	if _support.find_rule_mod_instance(kashimo, "nullify_field_accuracy") != null:
		return harness.fail_result("kyokyo nullify_field_accuracy should naturally expire after its full lifecycle")
	return harness.pass_result()

func _test_sukuna_vs_obito_interaction(harness, case_spec: Dictionary) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(String(case_spec.get("matchup_id", "")))
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("failed to build sukuna vs obito interaction setup: %s" % String(setup_result.get("error_message", "unknown error")))
	var battle_setup = setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, int(case_spec.get("battle_seed", 0)), battle_setup)
	var sukuna = battle_state.get_side("P1").get_active_unit()
	var obito = battle_state.get_side("P2").get_active_unit()
	if sukuna == null or obito == null:
		return harness.fail_result("missing active units for sukuna vs obito interaction")
	sukuna.current_mp = sukuna.max_mp
	sukuna.ultimate_points = sukuna.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_ultimate_command(core, 1, "P1", "P1-A", "sukuna_fukuma_mizushi"),
		_support.build_manual_skill_command(core, 1, "P2", "P2-A", "obito_qiudao_jiaotu"),
	])
	if _support.count_rule_mod_instances(sukuna, "incoming_heal_final_mod") != 1:
		return harness.fail_result("obito heal block should coexist on sukuna while malevolent shrine is active")
	if battle_state.field_state == null or String(battle_state.field_state.field_def_id) != "sukuna_malevolent_shrine_field":
		return harness.fail_result("malevolent shrine should remain active after the cross-role opening turn")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 2, "P1", "P1-A", "sukuna_hiraku"),
		_support.build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	if _support.count_effect_instances(obito, "sukuna_kamado_mark") != 1:
		return harness.fail_result("sukuna hiraku should successfully seed exactly one kamado stack before the switch/expire chain")
	var hp_before_switch := int(obito.current_hp)
	var replacement_preview = battle_state.get_side("P2").find_unit(String(battle_state.get_side("P2").bench_order[0])) if battle_state.get_side("P2").bench_order.size() > 0 else null
	var replacement_hp_before := int(replacement_preview.current_hp) if replacement_preview != null else -1
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 3, "P1", "P1-A"),
		_support.build_manual_switch_command(core, 3, "P2", "P2-A", "P2-B"),
	])
	if int(obito.current_hp) >= hp_before_switch:
		return harness.fail_result("kamado on_exit burst should damage obito before the replacement finishes entering")
	var replacement = battle_state.get_side("P2").get_active_unit()
	if replacement == null or String(replacement.public_id) != "P2-B":
		return harness.fail_result("obito side should finish the switch/expire chain on the replacement unit")
	if battle_state.field_state != null:
		return harness.fail_result("malevolent shrine should naturally expire on the same turn the marked target switches out")
	var expected_expire_damage := _sukuna_support.calc_expected_fixed_effect_damage(core, content_index, "sukuna_domain_expire_burst", replacement)
	if replacement_hp_before - int(replacement.current_hp) != expected_expire_damage:
		return harness.fail_result("malevolent shrine natural expire burst should still land on the replacement target after the switch chain")
	if _support.count_rule_mod_instances(sukuna, "incoming_heal_final_mod") != 0:
		return harness.fail_result("obito heal block should expire cleanly and not leak past the mixed domain lifecycle")
	return harness.pass_result()

func _test_kashimo_vs_obito_interaction(harness, case_spec: Dictionary) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(String(case_spec.get("matchup_id", "")))
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("failed to build kashimo vs obito interaction setup: %s" % String(setup_result.get("error_message", "unknown error")))
	var battle_setup = setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, int(case_spec.get("battle_seed", 0)), battle_setup)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var obito = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or obito == null:
		return harness.fail_result("missing active units for kashimo vs obito interaction")
	var yinyang_suite := ObitoRuntimeYinyangSuiteScript.new()
	var yinyang_result: Dictionary = yinyang_suite._test_obito_yinyang_dun_non_skill_segment_ignored_contract(harness)
	if not bool(yinyang_result.get("ok", false)):
		return yinyang_result
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_skill_command(core, 1, "P2", "P2-A", "obito_yinyang_dun"),
	])
	if _support.count_effect_instances(obito, "obito_yinyang_zhili") != 1:
		return harness.fail_result("obito yinyang guard should seed exactly one stack before the cross-role probe")
	kashimo.current_mp = kashimo.max_mp
	kashimo.ultimate_points = kashimo.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_ultimate_command(core, 2, "P1", "P1-A", "kashimo_phantom_beast_amber"),
		_support.build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	if not kashimo.has_used_once_per_battle_skill("kashimo_phantom_beast_amber"):
		return harness.fail_result("amber should persist its once_per_battle usage inside the kashimo vs obito chain")
	if _support.count_effect_instances(obito, "obito_yinyang_zhili") != 1:
		return harness.fail_result("obito yinyang listener must ignore amber self-damage and other non-incoming segment side effects")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_switch_command(core, 3, "P1", "P1-A", "P1-B"),
		_support.build_manual_wait_command(core, 3, "P2", "P2-A"),
	])
	if int(kashimo.persistent_stat_stages.get("attack", 0)) != 2 or int(kashimo.persistent_stat_stages.get("sp_attack", 0)) != 2:
		return harness.fail_result("amber persistent stages should survive the switch chain against obito")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_switch_command(core, 4, "P1", "P1-B", "P1-A"),
		_support.build_manual_wait_command(core, 4, "P2", "P2-A"),
	])
	if not kashimo.has_used_once_per_battle_skill("kashimo_phantom_beast_amber"):
		return harness.fail_result("amber once_per_battle usage must not be cleared by the switch chain")
	return harness.pass_result()

func _run_contracts(harness, contracts: Array) -> Dictionary:
	for contract in contracts:
		var result: Dictionary = contract.call()
		if not bool(result.get("ok", false)):
			return result if result.has("error") else harness.fail_result(str(result.get("error_message", "interaction contract failed")))
	return harness.pass_result()
