extends "res://test/support/gdunit_suite_bridge.gd"

const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const FormalCharacterSnapshotTestHelperScript := preload("res://tests/support/formal_character_snapshot_test_helper.gd")

var _helper = FormalCharacterSnapshotTestHelperScript.new()

func test_formal_character_snapshot_contract_matrix() -> void:
	_assert_legacy_result(_test_formal_character_snapshot_contract_matrix(_harness))

func _test_formal_character_snapshot_contract_matrix(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var character_ids: PackedStringArray = harness.build_formal_character_ids(sample_factory)
	if character_ids.is_empty():
		return harness.fail_result("formal character snapshot matrix requires at least one character")
	var content_index = harness.build_loaded_content_index(sample_factory)
	if content_index == null:
		return harness.fail_result("formal character snapshot matrix failed to load content snapshot")
	for character_id in character_ids:
		var result := _run_character_snapshot_contract(harness, content_index, String(character_id))
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()

func _run_character_snapshot_contract(harness, content_index, character_id: String) -> Dictionary:
	var checks := [
		{
			"label": "%s unit contract" % character_id,
			"content_map": content_index.units,
			"descriptors": [FormalCharacterBaselinesScript.unit_contract(character_id)],
			"id_key": "unit_id",
			"missing": "missing formal character unit definition",
		},
		{
			"label": "%s skill contracts" % character_id,
			"content_map": content_index.skills,
			"descriptors": FormalCharacterBaselinesScript.skill_contracts(character_id),
			"id_key": "skill_id",
			"missing": "missing formal character skill resource",
		},
		{
			"label": "%s passive contracts" % character_id,
			"content_map": content_index.passive_skills,
			"descriptors": FormalCharacterBaselinesScript.passive_contracts(character_id),
			"id_key": "passive_skill_id",
			"missing": "missing formal character passive resource",
		},
		{
			"label": "%s effect contracts" % character_id,
			"content_map": content_index.effects,
			"descriptors": FormalCharacterBaselinesScript.effect_contracts(character_id),
			"id_key": "effect_id",
			"missing": "missing formal character effect resource",
		},
		{
			"label": "%s field contracts" % character_id,
			"content_map": content_index.fields,
			"descriptors": FormalCharacterBaselinesScript.field_contracts(character_id),
			"id_key": "field_id",
			"missing": "missing formal character field resource",
		},
	]
	for check in checks:
		var descriptor_error := _descriptor_error(check.get("descriptors", []))
		if not descriptor_error.is_empty():
			return harness.fail_result("%s: %s" % [String(check.get("label", "")), descriptor_error])
		var result = _helper.run_descriptor_checks(
			harness,
			check.get("content_map", {}),
			check.get("descriptors", []),
			String(check.get("id_key", "")),
			"%s: %s" % [String(check.get("label", "")), String(check.get("missing", ""))]
		)
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()

func _descriptor_error(descriptors: Array) -> String:
	for raw_descriptor in descriptors:
		var message := FormalCharacterBaselinesScript.descriptor_error_message(raw_descriptor)
		if not message.is_empty():
			return message
	return ""
