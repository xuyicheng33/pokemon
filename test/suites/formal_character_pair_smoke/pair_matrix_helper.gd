extends RefCounted

func validate_directed_surface_matrix(harness, sample_factory, cases: Array) -> Dictionary:
	var formal_character_ids: PackedStringArray = harness.build_formal_character_ids(sample_factory)
	if formal_character_ids.size() < 2:
		return harness.fail_result("formal pair smoke requires at least two formal characters")
	var known_character_ids := _build_known_character_ids(formal_character_ids)
	var expected_pairs := {}
	for left_character_id in formal_character_ids:
		for right_character_id in formal_character_ids:
			if String(left_character_id) == String(right_character_id):
				continue
			expected_pairs[_directed_pair_key(String(left_character_id), String(right_character_id))] = true
	var actual_pairs := {}
	for raw_case_spec in cases:
		if not (raw_case_spec is Dictionary):
			return harness.fail_result("formal pair smoke case must be Dictionary")
		var case_spec: Dictionary = raw_case_spec
		var p1_character_id := String(case_spec.get("p1_character_id", "")).strip_edges()
		var p2_character_id := String(case_spec.get("p2_character_id", "")).strip_edges()
		if p1_character_id.is_empty() or p2_character_id.is_empty():
			return harness.fail_result("formal pair smoke case is missing p1/p2 character ids")
		if p1_character_id == p2_character_id:
			return harness.fail_result("formal pair smoke case must be directional and cannot target the same character on both sides")
		if not known_character_ids.has(p1_character_id) or not known_character_ids.has(p2_character_id):
			return harness.fail_result("formal pair smoke case references unknown formal character id")
		var pair_key := _directed_pair_key(p1_character_id, p2_character_id)
		if actual_pairs.has(pair_key):
			return harness.fail_result("formal pair smoke duplicated directed pair coverage: %s" % pair_key)
		actual_pairs[pair_key] = true
	return _validate_expected_pair_matrix(
		harness,
		expected_pairs,
		actual_pairs,
		"formal pair smoke missing directed pair coverage: %s",
		"formal pair smoke contains non-matrix directed pair coverage: %s"
	)

func validate_unordered_interaction_matrix(harness, sample_factory, cases: Array) -> Dictionary:
	var formal_character_ids: PackedStringArray = harness.build_formal_character_ids(sample_factory)
	if formal_character_ids.size() < 2:
		return harness.fail_result("formal pair interaction requires at least two formal characters")
	var known_character_ids := _build_known_character_ids(formal_character_ids)
	var expected_pairs := {}
	for left_index in range(formal_character_ids.size()):
		for right_index in range(left_index + 1, formal_character_ids.size()):
			expected_pairs[_unordered_pair_key(
				String(formal_character_ids[left_index]),
				String(formal_character_ids[right_index])
			)] = true
	var actual_pairs := {}
	for raw_case_spec in cases:
		if not (raw_case_spec is Dictionary):
			return harness.fail_result("formal pair interaction case must be Dictionary")
		var case_spec: Dictionary = raw_case_spec
		var character_ids = case_spec.get("character_ids", [])
		if not (character_ids is Array) or character_ids.size() != 2:
			return harness.fail_result("formal pair interaction case must define exactly two character_ids")
		var left_character_id := String(character_ids[0]).strip_edges()
		var right_character_id := String(character_ids[1]).strip_edges()
		if left_character_id.is_empty() or right_character_id.is_empty():
			return harness.fail_result("formal pair interaction case contains empty character_ids")
		if left_character_id == right_character_id:
			return harness.fail_result("formal pair interaction case cannot target the same character twice")
		if not known_character_ids.has(left_character_id) or not known_character_ids.has(right_character_id):
			return harness.fail_result("formal pair interaction case references unknown formal character id")
		if String(case_spec.get("scenario_key", "")).strip_edges().is_empty():
			return harness.fail_result("formal pair interaction case missing scenario_key")
		if String(case_spec.get("matchup_id", "")).strip_edges().is_empty():
			return harness.fail_result("formal pair interaction case missing matchup_id")
		if not _is_positive_whole_number(case_spec.get("battle_seed", null)):
			return harness.fail_result("formal pair interaction case missing positive integer battle_seed")
		actual_pairs[_unordered_pair_key(left_character_id, right_character_id)] = true
	return _validate_expected_pair_matrix(
		harness,
		expected_pairs,
		actual_pairs,
		"formal pair interaction missing unordered pair coverage: %s",
		"formal pair interaction contains non-matrix unordered pair coverage: %s"
	)

func find_case_by_test_name(cases: Array, test_name: String) -> Dictionary:
	for raw_case_spec in cases:
		if not (raw_case_spec is Dictionary):
			continue
		var case_spec: Dictionary = raw_case_spec
		if String(case_spec.get("test_name", "")) == test_name:
			return case_spec
	return {}

func _build_known_character_ids(formal_character_ids: PackedStringArray) -> Dictionary:
	var known_character_ids := {}
	for raw_character_id in formal_character_ids:
		known_character_ids[String(raw_character_id)] = true
	return known_character_ids

func _validate_expected_pair_matrix(
	harness,
	expected_pairs: Dictionary,
	actual_pairs: Dictionary,
	missing_message: String,
	extra_message: String
) -> Dictionary:
	var missing_pairs: Array[String] = []
	for expected_pair_key in expected_pairs.keys():
		if not actual_pairs.has(expected_pair_key):
			missing_pairs.append(String(expected_pair_key))
	missing_pairs.sort()
	if not missing_pairs.is_empty():
		return harness.fail_result(missing_message % ", ".join(missing_pairs))
	var extra_pairs: Array[String] = []
	for actual_pair_key in actual_pairs.keys():
		if not expected_pairs.has(actual_pair_key):
			extra_pairs.append(String(actual_pair_key))
	extra_pairs.sort()
	if not extra_pairs.is_empty():
		return harness.fail_result(extra_message % ", ".join(extra_pairs))
	return harness.pass_result()

func _directed_pair_key(left_character_id: String, right_character_id: String) -> String:
	return "%s->%s" % [left_character_id, right_character_id]

func _unordered_pair_key(left_character_id: String, right_character_id: String) -> String:
	var ordered_pair := [left_character_id, right_character_id]
	ordered_pair.sort()
	return "%s<->%s" % [ordered_pair[0], ordered_pair[1]]

func _is_positive_whole_number(value) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return numeric_value > 0.0 and is_equal_approx(numeric_value, floor(numeric_value))
