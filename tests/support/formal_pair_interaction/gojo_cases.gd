extends RefCounted
class_name FormalPairInteractionGojoCases

const GojoUnlimitedVoidContractSupportScript := preload("res://tests/support/gojo_unlimited_void_contract_support.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")
const ObitoRuntimeContractSupportScript := preload("res://tests/support/obito_runtime_contract_support.gd")

var _gojo_contracts = GojoUnlimitedVoidContractSupportScript.new()
var _kashimo_support = KashimoTestSupportScript.new()
var _obito_contracts = ObitoRuntimeContractSupportScript.new()

func build_runners() -> Dictionary:
	return {
		"gojo_sukuna_domain_cleanup": Callable(self, "run_gojo_vs_sukuna_domain_cleanup"),
		"gojo_kashimo_kyokyo_nullify_domain_accuracy": Callable(self, "run_gojo_vs_kashimo_kyokyo_nullify_domain_accuracy"),
		"gojo_obito_heal_block_public_contract": Callable(self, "run_gojo_vs_obito_heal_block_public_contract"),
	}

func run_gojo_vs_sukuna_domain_cleanup(harness, case_spec: Dictionary) -> Dictionary:
	var matchup_id := _require_matchup_id(harness, case_spec)
	if matchup_id.is_empty():
		return harness.fail_result("formal pair interaction case missing matchup_id")
	var battle_seed = case_spec.get("battle_seed", null)
	if typeof(battle_seed) != TYPE_INT or int(battle_seed) <= 0:
		return harness.fail_result("formal pair interaction case missing positive integer battle_seed")
	var base_seed := int(battle_seed)
	return _run_contracts(harness, [
		func() -> Dictionary:
			return _gojo_contracts.run_failed_clash_does_not_revive_action_lock_contract_for_matchup(harness, matchup_id, base_seed),
		func() -> Dictionary:
			return _gojo_contracts.run_expire_removes_field_buff_contract_for_matchup(harness, matchup_id, base_seed + 1),
		func() -> Dictionary:
			return _gojo_contracts.run_break_removes_field_buff_contract_for_matchup(harness, matchup_id, base_seed + 2),
	])

func run_gojo_vs_kashimo_kyokyo_nullify_domain_accuracy(harness, case_spec: Dictionary) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var matchup_id := _require_matchup_id(harness, case_spec)
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
		"gojo_unlimited_void",
		"gojo_ao",
		"gojo_unlimited_void_field",
		probe_config
	)
	if not bool(seed_result.get("ok", false)):
		return harness.fail_result(str(seed_result.get("error", "failed to find gojo domain accuracy probe seed")))
	var probe_seed := int(seed_result.get("seed", 0))
	var baseline_result = _kashimo_support.run_domain_accuracy_case_for_matchup(
		harness,
		sample_factory,
		false,
		probe_seed,
		matchup_id,
		"gojo_unlimited_void",
		"gojo_ao",
		"gojo_unlimited_void_field",
		probe_config
	)
	if not bool(baseline_result.get("ok", false)):
		return harness.fail_result(str(baseline_result.get("error", "baseline kashimo domain accuracy case failed")))
	if int(baseline_result.get("damage", 0)) <= 0:
		return harness.fail_result("gojo domain should force authored ao to hit before kyokyo is cast")
	var protected_result = _kashimo_support.run_domain_accuracy_case_for_matchup(
		harness,
		sample_factory,
		true,
		probe_seed,
		matchup_id,
		"gojo_unlimited_void",
		"gojo_ao",
		"gojo_unlimited_void_field",
		probe_config
	)
	if not bool(protected_result.get("ok", false)):
		return harness.fail_result(str(protected_result.get("error", "protected kashimo domain accuracy case failed")))
	if int(protected_result.get("damage", -1)) != 0:
		return harness.fail_result("kyokyo should restore gojo ao's original miss rate under a real gojo domain")
	if not bool(protected_result.get("nullify_active", false)):
		return harness.fail_result("kyokyo runtime path should apply nullify_field_accuracy before gojo ao resolves")
	return harness.pass_result()

func run_gojo_vs_obito_heal_block_public_contract(harness, case_spec: Dictionary) -> Dictionary:
	var matchup_id := _require_matchup_id(harness, case_spec)
	if matchup_id.is_empty():
		return harness.fail_result("formal pair interaction case missing matchup_id")
	var battle_seed = case_spec.get("battle_seed", null)
	if typeof(battle_seed) != TYPE_INT or int(battle_seed) <= 0:
		return harness.fail_result("formal pair interaction case missing positive integer battle_seed")
	var base_seed := int(battle_seed)
	var gojo_ritual_loadout := {0: PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])}
	var p1_overrides := gojo_ritual_loadout if matchup_id.begins_with("gojo_") else {}
	var p2_overrides := gojo_ritual_loadout if matchup_id.begins_with("obito_") else {}
	return _run_contracts(harness, [
		func() -> Dictionary:
			return _obito_contracts.run_qiudao_jiaotu_heal_block_contract_for_matchup(harness, matchup_id, base_seed, p1_overrides, p2_overrides),
		func() -> Dictionary:
			return _obito_contracts.run_qiudao_jiaotu_switch_persist_contract_for_matchup(harness, matchup_id, base_seed + 1),
		func() -> Dictionary:
			return _obito_contracts.run_qiudao_jiaotu_expire_sync_contract_for_matchup(harness, matchup_id, base_seed + 2),
	])

func _run_contracts(harness, contracts: Array) -> Dictionary:
	for contract in contracts:
		var result: Dictionary = contract.call()
		if not bool(result.get("ok", false)):
			return result if result.has("error") else harness.fail_result(str(result.get("error_message", "interaction contract failed")))
	return harness.pass_result()

func _require_matchup_id(_harness, case_spec: Dictionary) -> String:
	return String(case_spec.get("matchup_id", "")).strip_edges()

func _kashimo_probe_config(matchup_id: String) -> Dictionary:
	if matchup_id == "gojo_vs_kashimo":
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
