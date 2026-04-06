extends "res://tests/support/formal_character_test_support.gd"
class_name ObitoTestSupport

func build_obito_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_formal_character_setup_result(sample_factory, "obito_juubi_jinchuriki", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_obito_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_obito_setup_result(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides))

func build_obito_vs_gojo_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_matchup_setup_result(sample_factory, "obito_vs_gojo", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_obito_vs_gojo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_obito_vs_gojo_setup_result(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides))

func build_obito_mirror_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_matchup_setup_result(sample_factory, "obito_mirror", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_obito_mirror_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_obito_mirror_setup_result(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides))
