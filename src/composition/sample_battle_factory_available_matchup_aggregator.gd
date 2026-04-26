extends RefCounted
class_name SampleBattleFactoryAvailableMatchupAggregator

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

var baseline_matchup_catalog: SampleBattleFactoryBaselineMatchupCatalog = null
var formal_matchup_catalog: SampleBattleFactoryFormalMatchupCatalog = null

func available_matchups_result() -> Dictionary:
	if baseline_matchup_catalog == null:
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactoryAvailableMatchupAggregator missing baseline_matchup_catalog"
		)
	if formal_matchup_catalog == null:
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactoryAvailableMatchupAggregator missing formal_matchup_catalog"
		)
	var baseline_result: Dictionary = baseline_matchup_catalog.load_matchups_result()
	if not bool(baseline_result.get("ok", false)):
		return baseline_result
	var formal_result: Dictionary = formal_matchup_catalog.load_matchups_result()
	if not bool(formal_result.get("ok", false)):
		return formal_result
	var baseline_matchups: Dictionary = baseline_result.get("data", {}).get("matchups", {})
	var formal_matchups: Dictionary = formal_result.get("data", {}).get("matchups", {})
	var collision_id := _first_matchup_collision(baseline_matchups, formal_matchups)
	if not collision_id.is_empty():
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory matchup_id collides between baseline and formal catalogs: %s" % collision_id
		)
	var descriptors: Array = []
	_append_available_matchup_descriptors(descriptors, baseline_matchups, "baseline")
	_append_available_matchup_descriptors(descriptors, formal_matchups, "formal")
	return ResultEnvelopeHelperScript.ok(descriptors)

func _first_matchup_collision(left_matchups: Dictionary, right_matchups: Dictionary) -> String:
	for raw_matchup_id in left_matchups.keys():
		var matchup_id := String(raw_matchup_id).strip_edges()
		if not matchup_id.is_empty() and right_matchups.has(matchup_id):
			return matchup_id
	return ""

func _append_available_matchup_descriptors(descriptors: Array, raw_matchups, source: String) -> void:
	if not (raw_matchups is Dictionary):
		return
	for raw_matchup_id in raw_matchups.keys():
		var matchup_id := str(raw_matchup_id).strip_edges()
		var matchup_spec = raw_matchups.get(raw_matchup_id, {})
		if matchup_id.is_empty() or not (matchup_spec is Dictionary):
			continue
		descriptors.append({
			"matchup_id": matchup_id,
			"source": source,
			"p1_units": Array(matchup_spec.get("p1_units", [])).duplicate(true),
			"p2_units": Array(matchup_spec.get("p2_units", [])).duplicate(true),
			"test_only": bool(matchup_spec.get("test_only", false)),
		})

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)
