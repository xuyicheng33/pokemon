extends RefCounted
class_name FormalCharacterManifestPairInteractions

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const FormalRegistryContractsScript := preload("res://src/shared/formal_registry_contracts.gd")

const MATCHUP_INFIX := "_vs_"

var _registry_contracts = FormalRegistryContractsScript.new()

func derive_pair_interaction_cases_result(pair_interaction_specs: Array, pair_maps: Dictionary, matchups: Dictionary, manifest_path: String) -> Dictionary:
	var expected_pair_keys: Dictionary = {}
	var runtime_order: Array = pair_maps.get("runtime_order", [])
	for left_index in range(runtime_order.size()):
		for right_index in range(left_index + 1, runtime_order.size()):
			expected_pair_keys[_unordered_pair_key(String(runtime_order[left_index]), String(runtime_order[right_index]))] = true
	var seen_pair_keys: Dictionary = {}
	var seen_scenario_keys: Dictionary = {}
	var cases: Array = []
	for spec_index in range(pair_interaction_specs.size()):
		var raw_spec = pair_interaction_specs[spec_index]
		if not (raw_spec is Dictionary):
			return _error_result("FormalCharacterManifest[pair_interaction_specs][%d] must be dictionary: %s" % [spec_index, manifest_path])
		var spec: Dictionary = raw_spec.duplicate(true)
		var field_result := _registry_contracts.validate_required_fields_result(
			FormalRegistryContractsScript.PAIR_INTERACTION_SPEC_BUCKET,
			spec,
			"FormalCharacterManifest[pair_interaction_specs][%d]" % spec_index
		)
		if not bool(field_result.get("ok", false)):
			return field_result
		var character_ids = spec.get("character_ids", [])
		if not (character_ids is Array) or character_ids.size() != 2:
			return _error_result(
				"FormalCharacterManifest[pair_interaction_specs][%d].character_ids must contain exactly two entries: %s" % [spec_index, manifest_path]
			)
		var forward_character_id := String(character_ids[0]).strip_edges()
		var reverse_character_id := String(character_ids[1]).strip_edges()
		if forward_character_id.is_empty() or reverse_character_id.is_empty() or forward_character_id == reverse_character_id:
			return _error_result(
				"FormalCharacterManifest[pair_interaction_specs][%d].character_ids must contain two distinct non-empty entries: %s" % [spec_index, manifest_path]
			)
		if not pair_maps.get("known_character_ids", {}).has(forward_character_id) or not pair_maps.get("known_character_ids", {}).has(reverse_character_id):
			return _error_result(
				"FormalCharacterManifest[pair_interaction_specs][%d].character_ids must reference known formal characters: %s" % [spec_index, manifest_path]
			)
		var unordered_pair_key := _unordered_pair_key(forward_character_id, reverse_character_id)
		if seen_pair_keys.has(unordered_pair_key):
			return _error_result("FormalCharacterManifest duplicated pair_interaction_specs pair: %s (%s)" % [unordered_pair_key, manifest_path])
		var scenario_key := String(spec.get("scenario_key", "")).strip_edges()
		if seen_scenario_keys.has(scenario_key):
			return _error_result("FormalCharacterManifest duplicated pair_interaction_specs scenario_key: %s (%s)" % [scenario_key, manifest_path])
		seen_pair_keys[unordered_pair_key] = true
		seen_scenario_keys[scenario_key] = true
		var forward_case_result := _derived_interaction_case_result(
			pair_maps,
			matchups,
			forward_character_id,
			reverse_character_id,
			scenario_key,
			int(spec.get("forward_battle_seed", 0)),
			manifest_path
		)
		if not bool(forward_case_result.get("ok", false)):
			return forward_case_result
		cases.append(forward_case_result.get("data", {}).duplicate(true))
		var reverse_case_result := _derived_interaction_case_result(
			pair_maps,
			matchups,
			reverse_character_id,
			forward_character_id,
			scenario_key,
			int(spec.get("reverse_battle_seed", 0)),
			manifest_path
		)
		if not bool(reverse_case_result.get("ok", false)):
			return reverse_case_result
		cases.append(reverse_case_result.get("data", {}).duplicate(true))
	var missing_pair_keys: Array[String] = []
	for raw_pair_key in expected_pair_keys.keys():
		var pair_key := String(raw_pair_key)
		if not seen_pair_keys.has(pair_key):
			missing_pair_keys.append(pair_key)
	missing_pair_keys.sort()
	if not missing_pair_keys.is_empty():
		return _error_result(
			"FormalCharacterManifest missing pair_interaction_specs coverage: %s (%s)" % [", ".join(missing_pair_keys), manifest_path]
		)
	return _ok_result(cases)

func _derived_interaction_case_result(pair_maps: Dictionary, matchups: Dictionary, left_character_id: String, right_character_id: String, scenario_key: String, battle_seed: int, manifest_path: String) -> Dictionary:
	var matchup_id := _generated_matchup_id(pair_maps, left_character_id, right_character_id)
	if not matchups.has(matchup_id):
		return _error_result("FormalCharacterManifest missing generated matchup for pair_interaction_specs: %s (%s)" % [matchup_id, manifest_path])
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
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": ErrorCodesScript.INVALID_BATTLE_SETUP,
		"error_message": error_message,
	}
