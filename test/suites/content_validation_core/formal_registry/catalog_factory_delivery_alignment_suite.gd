extends "res://test/suites/content_validation_core/formal_registry/catalog_factory_shared.gd"

const PairSeedCasesScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_pair_seed_cases.gd")
const PairMatrixCasesScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_pair_matrix_cases.gd")

func test_formal_pair_interaction_catalog_seed_contract() -> void:
	_run_legacy_helper(PairSeedCasesScript, "_test_formal_pair_interaction_catalog_seed_contract", [_harness])

func test_formal_pair_interaction_catalog_direction_contract() -> void:
	_run_legacy_helper(PairMatrixCasesScript, "_test_formal_pair_interaction_catalog_direction_contract", [_harness])

func test_formal_pair_interaction_catalog_test_only_matchup_contract() -> void:
	_run_legacy_helper(PairMatrixCasesScript, "_test_formal_pair_interaction_catalog_test_only_matchup_contract", [_harness])
