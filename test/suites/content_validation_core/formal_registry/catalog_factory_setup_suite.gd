extends "res://test/suites/content_validation_core/formal_registry/catalog_factory_shared.gd"

func test_formal_character_shared_fire_burst_validation() -> void:
	_run_legacy_helper(SetupSharedScript, "_test_formal_character_shared_fire_burst_validation", [_harness])

func test_formal_character_setup_registry_runtime_contract() -> void:
	_run_legacy_helper(SetupSharedScript, "_test_formal_character_setup_registry_runtime_contract", [_harness])

func test_formal_character_auto_sample_matchup_contract() -> void:
	_run_legacy_helper(SetupSharedScript, "_test_formal_character_auto_sample_matchup_contract", [_harness])

func test_formal_character_registry_id_mismatch_contract() -> void:
	_run_legacy_helper(SetupMismatchSharedScript, "_test_formal_character_registry_id_mismatch_contract", [_harness])
