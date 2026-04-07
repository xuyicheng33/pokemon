extends "res://tests/suites/content_validation_core/formal_registry/shared.gd"

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("formal_character_delivery_registry_required_field_guard_contract", failures, Callable(self, "_test_formal_character_delivery_registry_required_field_guard_contract").bind(harness))

func _test_formal_character_delivery_registry_required_field_guard_contract(harness) -> Dictionary:
	var delivery_registry_path := "user://formal_character_delivery_registry_missing_field_fixture.json"
	var delivery_registry := FormalCharacterRegistryScript.new()
	var bad_cases: Array = [
		{
			"missing_key": "display_name",
			"expected_error": "missing display_name",
		},
		{
			"missing_key": "design_doc",
			"expected_error": "missing design_doc",
		},
		{
			"missing_key": "adjustment_doc",
			"expected_error": "missing adjustment_doc",
		},
		{
			"missing_key": "surface_smoke_skill_id",
			"expected_error": "missing surface_smoke_skill_id",
		},
		{
			"missing_key": "suite_path",
			"expected_error": "missing suite_path",
		},
		{
			"missing_key": "required_suite_paths",
			"expected_error": "missing required_suite_paths",
		},
		{
			"missing_key": "required_test_names",
			"expected_error": "missing required_test_names",
		},
		{
			"missing_key": "design_needles",
			"expected_error": "missing design_needles",
		},
		{
			"missing_key": "adjustment_needles",
			"expected_error": "missing adjustment_needles",
		},
	]
	for raw_case in bad_cases:
		var bad_case: Dictionary = raw_case
		var entry := _build_delivery_registry_entry(
			"gojo_alias",
			"Gojo Alias",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"tests/suites/gojo_suite.gd",
			["tests/suites/formal_character_pair_smoke_suite.gd"],
			["gojo_manager_smoke_contract"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		)
		entry.erase(String(bad_case.get("missing_key", "")))
		var delivery_registry_payload := JSON.stringify([entry], "  ")
		if not _write_json_fixture(delivery_registry_path, delivery_registry_payload):
			return harness.fail_result("failed to write missing-field delivery registry fixture")
		var load_result: Dictionary = delivery_registry.load_entries_from_path_result(delivery_registry_path)
		if bool(load_result.get("ok", false)):
			return harness.fail_result("delivery registry should fail fast on %s" % String(bad_case.get("expected_error", "")))
		var error_message := String(load_result.get("error", ""))
		var expected_error := String(bad_case.get("expected_error", ""))
		if error_message.find(expected_error) == -1:
			return harness.fail_result("delivery registry should report %s, got: %s" % [expected_error, error_message])
	return harness.pass_result()
