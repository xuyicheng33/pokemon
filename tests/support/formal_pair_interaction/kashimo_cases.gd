extends RefCounted
class_name FormalPairInteractionKashimoCases

const FormalCharacterTestSupportScript := preload("res://tests/support/formal_character_test_support.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")
const ObitoRuntimeContractSupportScript := preload("res://tests/support/obito_runtime_contract_support.gd")

var _formal_support = FormalCharacterTestSupportScript.new()
var _kashimo_support = KashimoTestSupportScript.new()
var _obito_contracts = ObitoRuntimeContractSupportScript.new()

func run_sukuna_vs_kashimo_domain_accuracy_nullified(harness, case_spec: Dictionary) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var matchup_id := String(case_spec.get("matchup_id", "")).strip_edges()
	if matchup_id.is_empty():
		return harness.fail_result("formal pair interaction case missing matchup_id")
	var battle_seed = case_spec.get("battle_seed", null)
	if typeof(battle_seed) != TYPE_INT or int(battle_seed) <= 0:
		return harness.fail_result("formal pair interaction case missing positive integer battle_seed")
	var probe_config := _kashimo_probe_config(matchup_id)
	var seed_result = _kashimo_support.find_domain_accuracy_probe_seed_for_matchup(
		harness,
		sample_factory,
		int(battle_seed),
		128,
		matchup_id,
		"sukuna_fukuma_mizushi",
		"sukuna_hiraku",
		"sukuna_malevolent_shrine_field",
		probe_config
	)
	if not bool(seed_result.get("ok", false)):
		return harness.fail_result(str(seed_result.get("error", "failed to find sukuna domain accuracy probe seed")))
	var probe_seed := int(seed_result.get("seed", 0))
	var baseline_result = _kashimo_support.run_domain_accuracy_case_for_matchup(
		harness,
		sample_factory,
		false,
		probe_seed,
		matchup_id,
		"sukuna_fukuma_mizushi",
		"sukuna_hiraku",
		"sukuna_malevolent_shrine_field",
		probe_config
	)
	if not bool(baseline_result.get("ok", false)):
		return harness.fail_result(str(baseline_result.get("error", "baseline sukuna domain accuracy case failed")))
	if int(baseline_result.get("damage", 0)) <= 0:
		return harness.fail_result("sukuna domain should force authored hiraku to hit before kyokyo is cast")
	var protected_result = _kashimo_support.run_domain_accuracy_case_for_matchup(
		harness,
		sample_factory,
		true,
		probe_seed,
		matchup_id,
		"sukuna_fukuma_mizushi",
		"sukuna_hiraku",
		"sukuna_malevolent_shrine_field",
		probe_config
	)
	if not bool(protected_result.get("ok", false)):
		return harness.fail_result(str(protected_result.get("error", "protected sukuna domain accuracy case failed")))
	if int(protected_result.get("damage", -1)) != 0:
		return harness.fail_result("kyokyo should restore sukuna hiraku's original miss rate under a real sukuna domain")
	if not bool(protected_result.get("nullify_active", false)):
		return harness.fail_result("kyokyo runtime path should apply nullify_field_accuracy before sukuna hiraku resolves")
	return harness.pass_result()

func run_kashimo_vs_obito_yinyang_and_amber_persistence(harness, case_spec: Dictionary) -> Dictionary:
	var preflight_result: Dictionary = _obito_contracts.run_yinyang_dun_non_skill_segment_ignored_contract(harness)
	if not bool(preflight_result.get("ok", false)):
		return preflight_result
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var matchup_id := String(case_spec.get("matchup_id", "")).strip_edges()
	if matchup_id.is_empty():
		return harness.fail_result("formal pair interaction case missing matchup_id")
	var battle_seed = case_spec.get("battle_seed", null)
	if typeof(battle_seed) != TYPE_INT or int(battle_seed) <= 0:
		return harness.fail_result("formal pair interaction case missing positive integer battle_seed")
	var setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(matchup_id)
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("failed to build kashimo vs obito interaction setup: %s" % String(setup_result.get("error_message", "unknown error")))
	var battle_setup = setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, int(battle_seed), battle_setup)
	var kashimo = _formal_support.find_unit_on_side(battle_state, "P1", "kashimo_hajime")
	if kashimo == null:
		kashimo = _formal_support.find_unit_on_side(battle_state, "P2", "kashimo_hajime")
	var obito = _formal_support.find_unit_on_side(battle_state, "P1", "obito_juubi_jinchuriki")
	if obito == null:
		obito = _formal_support.find_unit_on_side(battle_state, "P2", "obito_juubi_jinchuriki")
	if kashimo == null or obito == null:
		return harness.fail_result("missing active units for kashimo vs obito interaction")
	var kashimo_side_id := _side_id_for_public_id(String(kashimo.public_id))
	var obito_side_id := _side_id_for_public_id(String(obito.public_id))
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_formal_support.build_manual_wait_command(core, 1, kashimo_side_id, String(kashimo.public_id)),
		_formal_support.build_manual_skill_command(core, 1, obito_side_id, String(obito.public_id), "obito_yinyang_dun"),
	])
	if _formal_support.count_effect_instances(obito, "obito_yinyang_zhili") != 1:
		return harness.fail_result("obito yinyang guard should seed exactly one stack before the cross-role probe")
	kashimo.current_mp = kashimo.max_mp
	kashimo.ultimate_points = kashimo.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_formal_support.build_manual_ultimate_command(core, 2, kashimo_side_id, String(kashimo.public_id), "kashimo_phantom_beast_amber"),
		_formal_support.build_manual_wait_command(core, 2, obito_side_id, String(obito.public_id)),
	])
	if not kashimo.has_used_once_per_battle_skill("kashimo_phantom_beast_amber"):
		return harness.fail_result("amber should persist its once_per_battle usage inside the kashimo vs obito chain")
	if _formal_support.count_effect_instances(obito, "obito_yinyang_zhili") != 1:
		return harness.fail_result("obito yinyang listener must ignore amber self-damage and other non-incoming segment side effects")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_formal_support.build_manual_switch_command(core, 3, kashimo_side_id, String(kashimo.public_id), "%s-B" % kashimo_side_id),
		_formal_support.build_manual_wait_command(core, 3, obito_side_id, String(obito.public_id)),
	])
	if int(kashimo.persistent_stat_stages.get("attack", 0)) != 2 or int(kashimo.persistent_stat_stages.get("sp_attack", 0)) != 2:
		return harness.fail_result("amber persistent stages should survive the switch chain against obito")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_formal_support.build_manual_switch_command(core, 4, kashimo_side_id, "%s-B" % kashimo_side_id, "%s-A" % kashimo_side_id),
		_formal_support.build_manual_wait_command(core, 4, obito_side_id, String(obito.public_id)),
	])
	if not kashimo.has_used_once_per_battle_skill("kashimo_phantom_beast_amber"):
		return harness.fail_result("amber once_per_battle usage must not be cleared by the switch chain")
	return harness.pass_result()

func _kashimo_probe_config(matchup_id: String) -> Dictionary:
	if matchup_id == "sukuna_vs_kashimo":
		return {
			"protected_side_id": "P2",
			"override_side_id": "P2",
			"domain_side_id": "P1",
			"attack_side_id": "P1",
		}
	return {
		"protected_side_id": "P1",
		"override_side_id": "P1",
		"domain_side_id": "P2",
		"attack_side_id": "P2",
	}

func _side_id_for_public_id(public_id: String) -> String:
	return String(public_id).split("-", true, 1)[0]
