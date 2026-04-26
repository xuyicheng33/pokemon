extends "res://test/suites/content_validation_core/formal_registry/catalog_factory_shared.gd"

func test_formal_pair_surface_delivery_skill_contract() -> void:
	_run_legacy_helper(SurfaceSharedScript, "_test_formal_pair_surface_delivery_skill_contract", [_harness])

func test_formal_matchup_test_only_flag_contract() -> void:
	_run_legacy_helper(SurfaceSharedScript, "_test_formal_matchup_test_only_flag_contract", [_harness])
