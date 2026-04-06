extends RefCounted
class_name SampleBattleFactoryMatchupCatalog

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

const MATCHUP_SPECS := {
	"sample_default": {
		"p1_units": ["sample_pyron", "sample_mossaur", "sample_tidekit"],
		"p2_units": ["sample_tidekit", "sample_pyron", "sample_mossaur"],
	},
	"gojo_vs_sample": {
		"p1_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"],
		"p2_units": ["sample_pyron", "sample_tidekit", "sample_mossaur"],
	},
	"gojo_vs_sukuna": {
		"p1_units": ["gojo_satoru", "sample_mossaur", "sample_pyron"],
		"p2_units": ["sukuna", "sample_tidekit", "sample_mossaur"],
	},
	"sukuna_vs_sample": {
		"p1_units": ["sukuna", "sample_mossaur", "sample_tidekit"],
		"p2_units": ["sample_pyron", "sample_tidekit", "sample_mossaur"],
	},
	"sukuna_setup": {
		"p1_units": ["sukuna", "sample_mossaur", "sample_pyron"],
		"p2_units": ["sample_tidekit", "sample_pyron", "sample_mossaur"],
	},
	"sukuna_vs_gojo": {
		"p1_units": ["sukuna", "sample_tidekit", "sample_mossaur"],
		"p2_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"],
	},
	"kashimo_vs_sample": {
		"p1_units": ["kashimo_hajime", "sample_mossaur", "sample_pyron"],
		"p2_units": ["sample_tidekit", "sample_pyron", "sample_mossaur"],
	},
	"kashimo_vs_gojo": {
		"p1_units": ["kashimo_hajime", "sample_mossaur", "sample_pyron"],
		"p2_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"],
	},
	"obito_vs_sample": {
		"p1_units": ["obito_juubi_jinchuriki", "sample_mossaur", "sample_pyron"],
		"p2_units": ["sample_pyron", "sample_tidekit", "sample_mossaur"],
	},
	"obito_vs_gojo": {
		"p1_units": ["obito_juubi_jinchuriki", "sample_mossaur", "sample_pyron"],
		"p2_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"],
	},
	"obito_mirror": {
		"p1_units": ["obito_juubi_jinchuriki", "sample_mossaur", "sample_pyron"],
		"p2_units": ["obito_juubi_jinchuriki", "sample_tidekit", "sample_mossaur"],
	},
	"sample_vs_gojo": {
		"p1_units": ["sample_pyron", "sample_tidekit", "sample_mossaur"],
		"p2_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"],
	},
	"sukuna_vs_kashimo": {
		"p1_units": ["sukuna", "sample_mossaur", "sample_pyron"],
		"p2_units": ["kashimo_hajime", "sample_tidekit", "sample_mossaur"],
	},
	"sukuna_vs_obito": {
		"p1_units": ["sukuna", "sample_mossaur", "sample_pyron"],
		"p2_units": ["obito_juubi_jinchuriki", "sample_tidekit", "sample_mossaur"],
	},
	"kashimo_vs_obito": {
		"p1_units": ["kashimo_hajime", "sample_mossaur", "sample_pyron"],
		"p2_units": ["obito_juubi_jinchuriki", "sample_tidekit", "sample_mossaur"],
	},
	"gojo_vs_kashimo": {
		"p1_units": ["gojo_satoru", "sample_mossaur", "sample_pyron"],
		"p2_units": ["kashimo_hajime", "sample_tidekit", "sample_mossaur"],
	},
	"gojo_vs_obito": {
		"p1_units": ["gojo_satoru", "sample_mossaur", "sample_pyron"],
		"p2_units": ["obito_juubi_jinchuriki", "sample_tidekit", "sample_mossaur"],
	},
	"passive_item_vs_sample": {
		"p1_units": ["sample_pyron_charm", "sample_mossaur", "sample_tidekit"],
		"p2_units": ["sample_tidekit", "sample_pyron", "sample_mossaur"],
	},
}

const FORMAL_PAIR_SMOKE_CASES := [
	{
		"test_name": "formal_pair_gojo_vs_sukuna_manager_smoke_contract",
		"matchup_id": "gojo_vs_sukuna",
		"battle_seed": 1659,
		"p1_skill_id": "gojo_ao",
		"p2_skill_id": "sukuna_kai",
		"p1_definition_id": "gojo_satoru",
		"p2_definition_id": "sukuna",
	},
	{
		"test_name": "formal_pair_gojo_vs_kashimo_manager_smoke_contract",
		"matchup_id": "gojo_vs_kashimo",
		"battle_seed": 1660,
		"p1_skill_id": "gojo_ao",
		"p2_skill_id": "kashimo_charge",
		"p1_definition_id": "gojo_satoru",
		"p2_definition_id": "kashimo_hajime",
	},
	{
		"test_name": "formal_pair_gojo_vs_obito_manager_smoke_contract",
		"matchup_id": "gojo_vs_obito",
		"battle_seed": 1661,
		"p1_skill_id": "gojo_ao",
		"p2_skill_id": "obito_qiudao_jiaotu",
		"p1_definition_id": "gojo_satoru",
		"p2_definition_id": "obito_juubi_jinchuriki",
	},
	{
		"test_name": "formal_pair_sukuna_vs_kashimo_manager_smoke_contract",
		"matchup_id": "sukuna_vs_kashimo",
		"battle_seed": 1662,
		"p1_skill_id": "sukuna_kai",
		"p2_skill_id": "kashimo_charge",
		"p1_definition_id": "sukuna",
		"p2_definition_id": "kashimo_hajime",
	},
	{
		"test_name": "formal_pair_sukuna_vs_obito_manager_smoke_contract",
		"matchup_id": "sukuna_vs_obito",
		"battle_seed": 1663,
		"p1_skill_id": "sukuna_kai",
		"p2_skill_id": "obito_qiudao_jiaotu",
		"p1_definition_id": "sukuna",
		"p2_definition_id": "obito_juubi_jinchuriki",
	},
	{
		"test_name": "formal_pair_kashimo_vs_obito_manager_smoke_contract",
		"matchup_id": "kashimo_vs_obito",
		"battle_seed": 1664,
		"p1_skill_id": "kashimo_raiken",
		"p2_skill_id": "obito_yinyang_dun",
		"p1_definition_id": "kashimo_hajime",
		"p2_definition_id": "obito_juubi_jinchuriki",
	},
]

func has_matchup(matchup_id: String) -> bool:
	return MATCHUP_SPECS.has(matchup_id)

func build_setup(setup_builder, matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Variant:
	var result := build_setup_result(setup_builder, matchup_id, side_regular_skill_overrides)
	if not bool(result.get("ok", false)):
		return null
	return result.get("data", null)

func build_setup_result(setup_builder, matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var spec: Dictionary = MATCHUP_SPECS.get(matchup_id, {})
	if spec.is_empty():
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory unknown matchup_id: %s" % matchup_id
		)
	var battle_setup = setup_builder.build_matchup_setup(
		PackedStringArray(spec.get("p1_units", [])),
		PackedStringArray(spec.get("p2_units", [])),
		side_regular_skill_overrides
	)
	if battle_setup == null:
		return _error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build matchup setup: %s" % matchup_id
		)
	return _ok_result(battle_setup)

func formal_pair_smoke_cases() -> Array:
	var cases: Array = []
	for case_spec in FORMAL_PAIR_SMOKE_CASES:
		cases.append(case_spec.duplicate(true))
	return cases

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
