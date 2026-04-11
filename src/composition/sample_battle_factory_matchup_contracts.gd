extends RefCounted
class_name SampleBattleFactoryMatchupContracts

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func validate_matchups_result(matchups, source_label: String) -> Dictionary:
	if not (matchups is Dictionary):
		return _error_result("SampleBattleFactory %s missing dictionary matchups" % source_label)
	for raw_matchup_id in matchups.keys():
		var matchup_id := String(raw_matchup_id).strip_edges()
		var matchup_spec = matchups.get(raw_matchup_id, {})
		if not (matchup_spec is Dictionary):
			return _error_result("SampleBattleFactory %s[%s] must be dictionary" % [source_label, matchup_id])
		if matchup_spec.has("test_only") and not (matchup_spec.get("test_only") is bool):
			return _error_result("SampleBattleFactory %s[%s].test_only must be boolean" % [source_label, matchup_id])
		for side_key in ["p1_units", "p2_units"]:
			var units = matchup_spec.get(side_key, [])
			if not (units is Array) or units.is_empty():
				return _error_result("SampleBattleFactory %s[%s].%s must be non-empty array" % [source_label, matchup_id, side_key])
			for raw_unit_id in units:
				if String(raw_unit_id).strip_edges().is_empty():
					return _error_result("SampleBattleFactory %s[%s].%s contains empty unit_definition_id" % [source_label, matchup_id, side_key])
	return _ok_result(true)

func build_setup_result(setup_builder, matchups: Dictionary, matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var spec: Dictionary = matchups.get(matchup_id, {})
	if spec.is_empty():
		return _error_result("SampleBattleFactory unknown matchup_id: %s" % matchup_id, ErrorCodesScript.INVALID_BATTLE_SETUP)
	var battle_setup = setup_builder.build_matchup_setup(
		PackedStringArray(spec.get("p1_units", [])),
		PackedStringArray(spec.get("p2_units", [])),
		side_regular_skill_overrides
	)
	if battle_setup == null:
		return _error_result("SampleBattleFactory failed to build matchup setup: %s" % matchup_id, ErrorCodesScript.INVALID_COMPOSITION)
	return _ok_result(battle_setup)

func collect_unit_definition_ids(matchups: Dictionary) -> PackedStringArray:
	var seen: Dictionary = {}
	var unit_definition_ids := PackedStringArray()
	for raw_matchup in matchups.values():
		if not (raw_matchup is Dictionary):
			continue
		for side_key in ["p1_units", "p2_units"]:
			var units = raw_matchup.get(side_key, [])
			if not (units is Array):
				continue
			for raw_unit_id in units:
				var unit_definition_id := String(raw_unit_id).strip_edges()
				if unit_definition_id.is_empty() or seen.has(unit_definition_id):
					continue
				seen[unit_definition_id] = true
				unit_definition_ids.append(unit_definition_id)
	return unit_definition_ids

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_message: String, error_code: String = ErrorCodesScript.INVALID_BATTLE_SETUP) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
