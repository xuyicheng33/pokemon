extends RefCounted
class_name FormalCharacterManifestPairInteractionBuilder

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

const MATCHUP_INFIX := "_vs_"
const REQUIRED_BENCH_UNIT_COUNT := 2

func build_catalog_result(characters: Array, raw_matchups, manifest_path: String) -> Dictionary:
	var pair_maps_result := _build_pair_maps_result(characters, manifest_path)
	if not bool(pair_maps_result.get("ok", false)):
		return pair_maps_result
	var pair_maps: Dictionary = pair_maps_result.get("data", {})
	var explicit_matchups_result := _normalize_explicit_matchups_result(raw_matchups, pair_maps, manifest_path)
	if not bool(explicit_matchups_result.get("ok", false)):
		return explicit_matchups_result
	var merged_matchups_result := _merged_matchups_result(
		pair_maps,
		explicit_matchups_result.get("data", {}),
		manifest_path
	)
	if not bool(merged_matchups_result.get("ok", false)):
		return merged_matchups_result
	var merged_matchups: Dictionary = merged_matchups_result.get("data", {})
	var interaction_cases_result := _derive_pair_interaction_cases_result(
		characters,
		pair_maps,
		merged_matchups,
		manifest_path
	)
	if not bool(interaction_cases_result.get("ok", false)):
		return interaction_cases_result
	return _ok_result({
		"matchups": merged_matchups,
		"pair_interaction_cases": interaction_cases_result.get("data", []).duplicate(true),
	})

func _build_pair_maps_result(characters: Array, manifest_path: String) -> Dictionary:
	var runtime_order: Array = []
	var known_character_ids: Dictionary = {}
	var character_to_unit: Dictionary = {}
	var pair_token_by_character: Dictionary = {}
	var initiator_bench_by_character: Dictionary = {}
	var responder_bench_by_character: Dictionary = {}
	for entry_index in range(characters.size()):
		var raw_entry = characters[entry_index]
		if not (raw_entry is Dictionary):
			return _catalog_error_result(
				"FormalCharacterManifest[characters][%d] must be dictionary: %s" % [entry_index, manifest_path]
			)
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var unit_definition_id := String(entry.get("unit_definition_id", "")).strip_edges()
		if character_id.is_empty() or unit_definition_id.is_empty():
			return _catalog_error_result(
				"FormalCharacterManifest[characters][%d] missing runtime identity fields: %s" % [entry_index, manifest_path]
			)
		var pair_token := String(entry.get("pair_token", "")).strip_edges()
		if pair_token.is_empty():
			return _catalog_error_result(
				"FormalCharacterManifest[%s] missing pair_token: %s" % [character_id, manifest_path]
			)
		var initiator_bench_result := _normalize_catalog_bench_units_result(
			entry.get("pair_initiator_bench_unit_ids", null),
			"pair_initiator_bench_unit_ids",
			character_id,
			manifest_path
		)
		if not bool(initiator_bench_result.get("ok", false)):
			return initiator_bench_result
		var responder_bench_result := _normalize_catalog_bench_units_result(
			entry.get("pair_responder_bench_unit_ids", null),
			"pair_responder_bench_unit_ids",
			character_id,
			manifest_path
		)
		if not bool(responder_bench_result.get("ok", false)):
			return responder_bench_result
		if pair_token_by_character.values().has(pair_token):
			return _catalog_error_result("FormalCharacterManifest duplicated pair token: %s (%s)" % [pair_token, manifest_path])
		runtime_order.append(character_id)
		known_character_ids[character_id] = true
		character_to_unit[character_id] = unit_definition_id
		pair_token_by_character[character_id] = pair_token
		initiator_bench_by_character[character_id] = initiator_bench_result.get("data", []).duplicate(true)
		responder_bench_by_character[character_id] = responder_bench_result.get("data", []).duplicate(true)
	return _ok_result({
		"runtime_order": runtime_order,
		"known_character_ids": known_character_ids,
		"character_to_unit": character_to_unit,
		"pair_token_by_character": pair_token_by_character,
		"initiator_bench_by_character": initiator_bench_by_character,
		"responder_bench_by_character": responder_bench_by_character,
	})

func _normalize_explicit_matchups_result(raw_matchups, pair_maps: Dictionary, manifest_path: String) -> Dictionary:
	if not (raw_matchups is Dictionary):
		return _catalog_error_result("FormalCharacterManifest[matchups] must be dictionary: %s" % manifest_path)
	var known_units: Dictionary = {}
	for raw_character_id in pair_maps.get("runtime_order", []):
		var character_id := String(raw_character_id)
		known_units[String(pair_maps.get("character_to_unit", {}).get(character_id, ""))] = character_id
	var normalized_matchups: Dictionary = {}
	for raw_matchup_id in raw_matchups.keys():
		var matchup_id := String(raw_matchup_id).strip_edges()
		var matchup_spec = raw_matchups.get(raw_matchup_id, {})
		if matchup_id.is_empty() or not (matchup_spec is Dictionary):
			return _catalog_error_result(
				"FormalCharacterManifest[matchups][%s] must be non-empty dictionary: %s" % [str(raw_matchup_id), manifest_path]
			)
		var p1_units = matchup_spec.get("p1_units", null)
		var p2_units = matchup_spec.get("p2_units", null)
		if not (p1_units is Array) or p1_units.is_empty() or not (p2_units is Array) or p2_units.is_empty():
			return _catalog_error_result(
				"FormalCharacterManifest[matchups][%s] must define non-empty p1_units/p2_units: %s" % [matchup_id, manifest_path]
			)
		var test_only = matchup_spec.get("test_only", false)
		if matchup_spec.has("test_only") and not (test_only is bool):
			return _catalog_error_result("FormalCharacterManifest[matchups][%s].test_only must be boolean: %s" % [matchup_id, manifest_path])
		var p1_character_id := String(known_units.get(String(p1_units[0]).strip_edges(), "")).strip_edges()
		var p2_character_id := String(known_units.get(String(p2_units[0]).strip_edges(), "")).strip_edges()
		if not p1_character_id.is_empty() and p1_character_id == p2_character_id and not bool(test_only):
			return _catalog_error_result(
				"FormalCharacterManifest[matchups][%s] same-character matchup must declare test_only: %s" % [matchup_id, manifest_path]
			)
		if not p1_character_id.is_empty() and not p2_character_id.is_empty() and p1_character_id != p2_character_id and not bool(test_only):
			return _catalog_error_result(
				"FormalCharacterManifest[matchups][%s] explicit formal pair matchup is no longer allowed; generated from characters instead: %s" % [matchup_id, manifest_path]
			)
		normalized_matchups[matchup_id] = matchup_spec.duplicate(true)
	return _ok_result(normalized_matchups)

func _merged_matchups_result(pair_maps: Dictionary, explicit_matchups: Dictionary, manifest_path: String) -> Dictionary:
	var merged_matchups: Dictionary = explicit_matchups.duplicate(true)
	for raw_left_character_id in pair_maps.get("runtime_order", []):
		var left_character_id := String(raw_left_character_id)
		for raw_right_character_id in pair_maps.get("runtime_order", []):
			var right_character_id := String(raw_right_character_id)
			if left_character_id == right_character_id:
				continue
			var matchup_id := _generated_matchup_id(pair_maps, left_character_id, right_character_id)
			if merged_matchups.has(matchup_id):
				return _catalog_error_result("FormalCharacterManifest generated matchup collides with explicit matchup: %s (%s)" % [matchup_id, manifest_path])
			merged_matchups[matchup_id] = {
				"p1_units": [pair_maps.get("character_to_unit", {}).get(left_character_id, "")] + pair_maps.get("initiator_bench_by_character", {}).get(left_character_id, []),
				"p2_units": [pair_maps.get("character_to_unit", {}).get(right_character_id, "")] + pair_maps.get("responder_bench_by_character", {}).get(right_character_id, []),
			}
	return _ok_result(merged_matchups)

func _normalize_catalog_bench_units_result(raw_bench_units, field_name: String, character_id: String, manifest_path: String) -> Dictionary:
	if not (raw_bench_units is Array):
		return _catalog_error_result("FormalCharacterManifest[%s].%s must be array: %s" % [character_id, field_name, manifest_path])
	if raw_bench_units.size() != REQUIRED_BENCH_UNIT_COUNT:
		return _catalog_error_result(
			"FormalCharacterManifest[%s].%s must contain exactly %d unit ids: %s" % [character_id, field_name, REQUIRED_BENCH_UNIT_COUNT, manifest_path]
		)
	var normalized_bench_units: Array = []
	var seen_bench_units: Dictionary = {}
	for raw_unit_definition_id in raw_bench_units:
		var unit_definition_id := String(raw_unit_definition_id).strip_edges()
		if unit_definition_id.is_empty() or seen_bench_units.has(unit_definition_id):
			return _catalog_error_result(
				"FormalCharacterManifest[%s].%s must contain distinct non-empty unit ids: %s" % [character_id, field_name, manifest_path]
			)
		seen_bench_units[unit_definition_id] = true
		normalized_bench_units.append(unit_definition_id)
	return _ok_result(normalized_bench_units)

func _derive_pair_interaction_cases_result(characters: Array, pair_maps: Dictionary, matchups: Dictionary, manifest_path: String) -> Dictionary:
	var runtime_order: Array = pair_maps.get("runtime_order", [])
	var character_index_by_id: Dictionary = {}
	for character_index in range(runtime_order.size()):
		character_index_by_id[String(runtime_order[character_index])] = character_index
	var seen_unordered_pairs: Dictionary = {}
	var seen_scenario_keys: Dictionary = {}
	var cases: Array = []
	for owner_index in range(characters.size()):
		var raw_entry = characters[owner_index]
		if not (raw_entry is Dictionary):
			return _catalog_error_result("FormalCharacterManifest[characters][%d] must be dictionary: %s" % [owner_index, manifest_path])
		var entry: Dictionary = raw_entry
		var owner_character_id := String(entry.get("character_id", "")).strip_edges()
		var owned_specs = entry.get("owned_pair_interaction_specs", [])
		if not (owned_specs is Array):
			return _catalog_error_result(
				"FormalCharacterManifest[%s].owned_pair_interaction_specs must be array: %s" % [owner_character_id, manifest_path]
			)
		var expected_other_character_ids: Array[String] = []
		for previous_index in range(owner_index):
			expected_other_character_ids.append(String(runtime_order[previous_index]).strip_edges())
		var seen_other_character_ids: Dictionary = {}
		for spec_index in range(owned_specs.size()):
			var raw_spec = owned_specs[spec_index]
			if not (raw_spec is Dictionary):
				return _catalog_error_result(
					"FormalCharacterManifest[%s].owned_pair_interaction_specs[%d] must be dictionary: %s" % [
						owner_character_id,
						spec_index,
						manifest_path,
					]
				)
			var spec: Dictionary = raw_spec
			var other_character_id := String(spec.get("other_character_id", "")).strip_edges()
			if not character_index_by_id.has(other_character_id):
				return _catalog_error_result(
					"FormalCharacterManifest[%s].owned_pair_interaction_specs[%d] references unknown other_character_id: %s (%s)" % [
						owner_character_id,
						spec_index,
						other_character_id,
						manifest_path,
					]
				)
			if int(character_index_by_id.get(other_character_id, -1)) >= owner_index:
				return _catalog_error_result(
					"FormalCharacterManifest[%s].owned_pair_interaction_specs[%d] must only target earlier manifest characters: %s (%s)" % [
						owner_character_id,
						spec_index,
						other_character_id,
						manifest_path,
					]
				)
			if seen_other_character_ids.has(other_character_id):
				return _catalog_error_result(
					"FormalCharacterManifest[%s] duplicated owned pair interaction target: %s (%s)" % [
						owner_character_id,
						other_character_id,
						manifest_path,
					]
				)
			seen_other_character_ids[other_character_id] = true
			var unordered_pair_key := _unordered_pair_key(owner_character_id, other_character_id)
			if seen_unordered_pairs.has(unordered_pair_key):
				return _catalog_error_result(
					"FormalCharacterManifest duplicated owned pair interaction pair: %s (%s)" % [unordered_pair_key, manifest_path]
				)
			seen_unordered_pairs[unordered_pair_key] = true
			var scenario_key := String(spec.get("scenario_key", "")).strip_edges()
			if seen_scenario_keys.has(scenario_key):
				return _catalog_error_result("FormalCharacterManifest duplicated owned pair interaction scenario_key: %s (%s)" % [scenario_key, manifest_path])
			seen_scenario_keys[scenario_key] = true
			var owner_initiator_case_result := _derived_interaction_case_result(
				pair_maps,
				matchups,
				owner_character_id,
				other_character_id,
				scenario_key,
				int(spec.get("owner_as_initiator_battle_seed", 0)),
				manifest_path
			)
			if not bool(owner_initiator_case_result.get("ok", false)):
				return owner_initiator_case_result
			cases.append(owner_initiator_case_result.get("data", {}).duplicate(true))
			var owner_responder_case_result := _derived_interaction_case_result(
				pair_maps,
				matchups,
				other_character_id,
				owner_character_id,
				scenario_key,
				int(spec.get("owner_as_responder_battle_seed", 0)),
				manifest_path
			)
			if not bool(owner_responder_case_result.get("ok", false)):
				return owner_responder_case_result
			cases.append(owner_responder_case_result.get("data", {}).duplicate(true))
		var missing_other_character_ids: Array[String] = []
		for other_character_id in expected_other_character_ids:
			if not seen_other_character_ids.has(other_character_id):
				missing_other_character_ids.append(other_character_id)
		missing_other_character_ids.sort()
		if not missing_other_character_ids.is_empty():
			return _catalog_error_result(
				"FormalCharacterManifest[%s] missing owned_pair_interaction_specs coverage for earlier characters: %s (%s)" % [
					owner_character_id,
					", ".join(missing_other_character_ids),
					manifest_path,
				]
			)
	return _ok_result(cases)

func _derived_interaction_case_result(pair_maps: Dictionary, matchups: Dictionary, left_character_id: String, right_character_id: String, scenario_key: String, battle_seed: int, manifest_path: String) -> Dictionary:
	var matchup_id := _generated_matchup_id(pair_maps, left_character_id, right_character_id)
	if not matchups.has(matchup_id):
		return _catalog_error_result("FormalCharacterManifest missing generated matchup for owned_pair_interaction_specs: %s (%s)" % [matchup_id, manifest_path])
	return _ok_result({
		"test_name": "formal_pair_%s_interaction_contract" % matchup_id,
		"scenario_key": scenario_key,
		"character_ids": [left_character_id, right_character_id],
		"matchup_id": matchup_id,
		"battle_seed": battle_seed,
	})

func _generated_matchup_id(pair_maps: Dictionary, left_character_id: String, right_character_id: String) -> String:
	return "%s%s%s" % [
		String(pair_maps.get("pair_token_by_character", {}).get(left_character_id, "")).strip_edges(),
		MATCHUP_INFIX,
		String(pair_maps.get("pair_token_by_character", {}).get(right_character_id, "")).strip_edges(),
	]

func _unordered_pair_key(left_character_id: String, right_character_id: String) -> String:
	var ordered_pair := [left_character_id, right_character_id]
	ordered_pair.sort()
	return "%s<->%s" % [ordered_pair[0], ordered_pair[1]]

func _ok_result(data) -> Dictionary:
	return ResultEnvelopeHelperScript.ok(data)

func _catalog_error_result(error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(ErrorCodesScript.INVALID_BATTLE_SETUP, error_message)
