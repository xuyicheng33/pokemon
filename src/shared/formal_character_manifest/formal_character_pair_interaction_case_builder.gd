extends RefCounted
class_name FormalCharacterPairInteractionCaseBuilder

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

const MATCHUP_INFIX := "_vs_"

func derive_pair_interaction_cases_result(characters: Array, pair_maps: Dictionary, matchups: Dictionary, manifest_path: String) -> Dictionary:
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
	return ResultEnvelopeHelperScript.ok(cases)

func _derived_interaction_case_result(pair_maps: Dictionary, matchups: Dictionary, left_character_id: String, right_character_id: String, scenario_key: String, battle_seed: int, manifest_path: String) -> Dictionary:
	var matchup_id := _generated_matchup_id(pair_maps, left_character_id, right_character_id)
	if not matchups.has(matchup_id):
		return _catalog_error_result("FormalCharacterManifest missing generated matchup for owned_pair_interaction_specs: %s (%s)" % [matchup_id, manifest_path])
	return ResultEnvelopeHelperScript.ok({
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

func _catalog_error_result(error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(ErrorCodesScript.INVALID_BATTLE_SETUP, error_message)
