extends RefCounted
class_name FormalCharacterPairSmokeSuite

const SurfaceSuiteScript := preload("res://tests/suites/formal_character_pair_smoke/surface_suite.gd")
const InteractionSuiteScript := preload("res://tests/suites/formal_character_pair_smoke/interaction_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	SurfaceSuiteScript.new().register_tests(runner, failures, harness)
	InteractionSuiteScript.new().register_tests(runner, failures, harness)
