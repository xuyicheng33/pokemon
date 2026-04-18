extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

const PairSeedCasesScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_pair_seed_cases.gd")
const PairMatrixCasesScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_pair_matrix_cases.gd")

func _test_formal_pair_interaction_catalog_seed_contract(harness) -> Dictionary:
	return _call_helper(PairSeedCasesScript, "_test_formal_pair_interaction_catalog_seed_contract", [harness])

func _test_formal_pair_interaction_catalog_direction_contract(harness) -> Dictionary:
	return _call_helper(PairMatrixCasesScript, "_test_formal_pair_interaction_catalog_direction_contract", [harness])

func _test_formal_pair_interaction_catalog_test_only_matchup_contract(harness) -> Dictionary:
	return _call_helper(PairMatrixCasesScript, "_test_formal_pair_interaction_catalog_test_only_matchup_contract", [harness])

func _call_helper(script_ref, method_name: String, args: Array = []) -> Dictionary:
	var helper = script_ref.new()
	var result: Dictionary = helper.callv(method_name, args)
	helper.free()
	return result
