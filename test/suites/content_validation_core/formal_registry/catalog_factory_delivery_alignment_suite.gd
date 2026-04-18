extends "res://test/suites/content_validation_core/formal_registry/catalog_factory_shared.gd"

func test_formal_pair_interaction_catalog_seed_contract() -> void:
	_assert_legacy_result(_test_formal_pair_interaction_catalog_seed_contract(_harness))

func test_formal_pair_interaction_catalog_direction_contract() -> void:
	_assert_legacy_result(_test_formal_pair_interaction_catalog_direction_contract(_harness))

func test_formal_pair_interaction_catalog_test_only_matchup_contract() -> void:
	_assert_legacy_result(_test_formal_pair_interaction_catalog_test_only_matchup_contract(_harness))
