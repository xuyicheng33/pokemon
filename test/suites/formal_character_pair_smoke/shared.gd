extends RefCounted

const PairMatrixHelperScript := preload("res://test/suites/formal_character_pair_smoke/pair_matrix_helper.gd")
const PairSurfaceRuntimeHelperScript := preload("res://test/suites/formal_character_pair_smoke/pair_surface_runtime_helper.gd")

var _matrix_helper = PairMatrixHelperScript.new()
var _runtime_helper = PairSurfaceRuntimeHelperScript.new()

func validate_directed_surface_matrix(harness, sample_factory, cases: Array) -> Dictionary:
	return _matrix_helper.validate_directed_surface_matrix(harness, sample_factory, cases)

func validate_unordered_interaction_matrix(harness, sample_factory, cases: Array) -> Dictionary:
	return _matrix_helper.validate_unordered_interaction_matrix(harness, sample_factory, cases)

func find_case_by_test_name(cases: Array, test_name: String) -> Dictionary:
	return _matrix_helper.find_case_by_test_name(cases, test_name)

func run_surface_case(harness, sample_factory, case_spec: Dictionary) -> Dictionary:
	return _runtime_helper.run_surface_case(harness, sample_factory, case_spec)
