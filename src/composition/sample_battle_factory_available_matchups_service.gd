extends RefCounted
class_name SampleBattleFactoryAvailableMatchupsService

var baseline_matchup_catalog
var formal_matchup_catalog

func available_matchups_result() -> Dictionary:
	var descriptors: Array = []
	var baseline_result: Dictionary = baseline_matchup_catalog.load_matchups_result()
	if not bool(baseline_result.get("ok", false)):
		return baseline_result
	_append_available_matchup_descriptors(
		descriptors,
		baseline_result.get("data", {}).get("matchups", {}),
		"baseline"
	)
	var formal_result: Dictionary = formal_matchup_catalog.load_matchups_result()
	if not bool(formal_result.get("ok", false)):
		return formal_result
	_append_available_matchup_descriptors(
		descriptors,
		formal_result.get("data", {}).get("matchups", {}),
		"formal"
	)
	return {
		"ok": true,
		"data": descriptors,
		"error_code": null,
		"error_message": null,
	}

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
