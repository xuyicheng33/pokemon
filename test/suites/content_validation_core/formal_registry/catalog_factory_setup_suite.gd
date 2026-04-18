extends "res://test/suites/content_validation_core/formal_registry/catalog_factory_shared.gd"

func test_formal_character_shared_fire_burst_validation() -> void:
	_assert_legacy_result(_test_formal_character_shared_fire_burst_validation(_harness))

func test_formal_character_setup_registry_runtime_contract() -> void:
	_assert_legacy_result(_test_formal_character_setup_registry_runtime_contract(_harness))

func test_formal_character_registry_id_mismatch_contract() -> void:
	_assert_legacy_result(_test_formal_character_registry_id_mismatch_contract(_harness))
