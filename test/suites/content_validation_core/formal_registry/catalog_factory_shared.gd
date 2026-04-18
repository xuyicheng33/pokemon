extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

const SetupSharedScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_setup_shared.gd")
const PairSharedScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_pair_shared.gd")
const SurfaceSharedScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_surface_shared.gd")

func _test_formal_character_shared_fire_burst_validation(harness) -> Dictionary:
	return _call_helper(SetupSharedScript, "_test_formal_character_shared_fire_burst_validation", [harness])

func _test_formal_character_setup_registry_runtime_contract(harness) -> Dictionary:
	return _call_helper(SetupSharedScript, "_test_formal_character_setup_registry_runtime_contract", [harness])

func _test_formal_character_registry_id_mismatch_contract(harness) -> Dictionary:
	return _call_helper(SetupSharedScript, "_test_formal_character_registry_id_mismatch_contract", [harness])

func _test_formal_pair_interaction_catalog_seed_contract(harness) -> Dictionary:
	return _call_helper(PairSharedScript, "_test_formal_pair_interaction_catalog_seed_contract", [harness])

func _test_formal_pair_interaction_catalog_direction_contract(harness) -> Dictionary:
	return _call_helper(PairSharedScript, "_test_formal_pair_interaction_catalog_direction_contract", [harness])

func _test_formal_pair_interaction_catalog_test_only_matchup_contract(harness) -> Dictionary:
	return _call_helper(PairSharedScript, "_test_formal_pair_interaction_catalog_test_only_matchup_contract", [harness])

func _test_formal_pair_surface_delivery_skill_contract(harness) -> Dictionary:
	return _call_helper(SurfaceSharedScript, "_test_formal_pair_surface_delivery_skill_contract", [harness])

func _test_formal_matchup_test_only_flag_contract(harness) -> Dictionary:
	return _call_helper(SurfaceSharedScript, "_test_formal_matchup_test_only_flag_contract", [harness])

func _call_helper(script_ref, method_name: String, args: Array = []) -> Dictionary:
	var helper = script_ref.new()
	var result: Dictionary = helper.callv(method_name, args)
	helper.free()
	return result
