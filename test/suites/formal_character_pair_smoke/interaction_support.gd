extends RefCounted

const TestSupportScript := preload("res://tests/support/formal_pair_interaction_test_support.gd")

var _support = TestSupportScript.new()

func validate_case_catalog(harness, interaction_cases: Array) -> Dictionary:
	return _support.validate_case_catalog(harness, interaction_cases)

func run_case(harness, case_spec: Dictionary) -> Dictionary:
	return _support.run_case(harness, case_spec)
