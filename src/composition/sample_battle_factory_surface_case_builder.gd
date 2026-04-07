extends RefCounted
class_name SampleBattleFactorySurfaceCaseBuilder

const FormalContractsScript := preload("res://src/composition/sample_battle_factory_formal_contracts.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const SURFACE_SMOKE_SEED_BASE := 1659

var _formal_contracts = FormalContractsScript.new()

func build_surface_cases_result(catalog: Dictionary, runtime_entries: Array, delivery_entries: Array) -> Dictionary:
	var runtime_maps_result := _formal_contracts.build_runtime_registry_maps_result(runtime_entries)
	if not bool(runtime_maps_result.get("ok", false)):
		return runtime_maps_result
	var delivery_maps_result := _formal_contracts.build_delivery_registry_maps_result(delivery_entries)
	if not bool(delivery_maps_result.get("ok", false)):
		return delivery_maps_result
	var runtime_maps: Dictionary = runtime_maps_result.get("data", {})
	var delivery_maps: Dictionary = delivery_maps_result.get("data", {})
	var runtime_order: Array = runtime_maps.get("runtime_order", [])
	var character_to_unit: Dictionary = runtime_maps.get("character_to_unit", {})
	var unit_to_character: Dictionary = runtime_maps.get("unit_to_character", {})
	var surface_skill_by_character: Dictionary = delivery_maps.get("surface_skill_by_character", {})
	var runtime_character_ids: Dictionary = {}
	for raw_character_id in runtime_order:
		runtime_character_ids[String(raw_character_id)] = true
	var delivery_character_ids: Dictionary = delivery_maps.get("delivery_character_ids", {})
	for character_id in runtime_character_ids.keys():
		if not delivery_character_ids.has(character_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry missing formal character_id: %s" % String(character_id)
			)
	for character_id in delivery_character_ids.keys():
		if not runtime_character_ids.has(character_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry references unknown formal character_id: %s" % String(character_id)
			)
	var matchup_pairs_result := _build_surface_matchup_pairs_result(catalog.get("matchups", {}), unit_to_character)
	if not bool(matchup_pairs_result.get("ok", false)):
		return matchup_pairs_result
	var matchup_by_pair: Dictionary = matchup_pairs_result.get("data", {}).get("matchup_by_pair", {})
	var cases: Array = []
	for raw_left_character_id in runtime_order:
		var left_character_id := String(raw_left_character_id).strip_edges()
		for raw_right_character_id in runtime_order:
			var right_character_id := String(raw_right_character_id).strip_edges()
			if left_character_id == right_character_id:
				continue
			var pair_key := _directed_pair_key(left_character_id, right_character_id)
			if not matchup_by_pair.has(pair_key):
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory missing formal directed matchup for surface smoke: %s" % pair_key
				)
			var p1_skill_id := String(surface_skill_by_character.get(left_character_id, "")).strip_edges()
			var p2_skill_id := String(surface_skill_by_character.get(right_character_id, "")).strip_edges()
			if p1_skill_id.is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory delivery registry[%s] missing surface_smoke_skill_id" % left_character_id
				)
			if p2_skill_id.is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory delivery registry[%s] missing surface_smoke_skill_id" % right_character_id
				)
			var matchup_id := String(matchup_by_pair.get(pair_key, "")).strip_edges()
			cases.append({
				"test_name": "formal_pair_%s_manager_smoke_contract" % matchup_id,
				"matchup_id": matchup_id,
				"battle_seed": SURFACE_SMOKE_SEED_BASE + cases.size(),
				"p1_character_id": left_character_id,
				"p2_character_id": right_character_id,
				"p1_unit_definition_id": String(character_to_unit.get(left_character_id, "")).strip_edges(),
				"p2_unit_definition_id": String(character_to_unit.get(right_character_id, "")).strip_edges(),
				"p1_skill_id": p1_skill_id,
				"p2_skill_id": p2_skill_id,
			})
	return _ok_result(cases)

func _build_surface_matchup_pairs_result(matchups: Dictionary, unit_to_character: Dictionary) -> Dictionary:
	var matchup_by_pair: Dictionary = {}
	for raw_matchup_id in matchups.keys():
		var matchup_id := String(raw_matchup_id).strip_edges()
		var matchup_spec = matchups.get(raw_matchup_id, {})
		if not (matchup_spec is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[%s] must be dictionary" % matchup_id
			)
		var p1_units = matchup_spec.get("p1_units", [])
		var p2_units = matchup_spec.get("p2_units", [])
		if not (p1_units is Array) or p1_units.is_empty() or not (p2_units is Array) or p2_units.is_empty():
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory matchup catalog[%s] must define non-empty p1_units/p2_units" % matchup_id
			)
		var p1_character_id := String(unit_to_character.get(String(p1_units[0]).strip_edges(), "")).strip_edges()
		var p2_character_id := String(unit_to_character.get(String(p2_units[0]).strip_edges(), "")).strip_edges()
		if p1_character_id.is_empty() or p2_character_id.is_empty() or p1_character_id == p2_character_id:
			continue
		var pair_key := _directed_pair_key(p1_character_id, p2_character_id)
		if matchup_by_pair.has(pair_key):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory duplicated formal directed matchup for surface smoke: %s" % pair_key
			)
		matchup_by_pair[pair_key] = matchup_id
	return _ok_result({
		"matchup_by_pair": matchup_by_pair,
	})

func _directed_pair_key(left_character_id: String, right_character_id: String) -> String:
	return "%s->%s" % [left_character_id, right_character_id]

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
