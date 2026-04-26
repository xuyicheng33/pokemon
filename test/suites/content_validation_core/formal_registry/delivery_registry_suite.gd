extends "res://test/suites/content_validation_core/formal_registry/shared.gd"


func test_formal_character_delivery_registry_required_field_guard_contract() -> void:
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
			"missing_key": "shared_capability_ids",
			"expected_error": "missing shared_capability_ids",
		},
	]
	for raw_case in bad_cases:
		var bad_case: Dictionary = raw_case
		var missing_key := String(bad_case.get("missing_key", "")).strip_edges()
		var manifest_path := "user://formal_character_manifest_delivery_missing_field_%s_fixture.json" % missing_key
		var entry := _build_manifest_character_entry(
			"gojo_alias",
			"Gojo Alias",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"test/suites/gojo_setup_and_markers_suite.gd",
			["test/suites/formal_character_pair_smoke/surface_suite.gd"],
			["formal_character_manager_public_contract_matrix"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		)
		entry.erase(missing_key)
		var manifest_payload := JSON.stringify(_build_manifest_payload([entry]), "  ")
		if not _write_json_fixture(manifest_path, manifest_payload):
			fail("failed to write missing-field manifest fixture")
			return
		var load_result: Dictionary = delivery_registry.load_entries_from_path_result(manifest_path)
		if bool(load_result.get("ok", false)):
			fail("formal manifest should fail fast on %s" % String(bad_case.get("expected_error", "")))
			return
		var error_message := String(load_result.get("error", ""))
		var expected_error := String(bad_case.get("expected_error", ""))
		if error_message.find(expected_error) == -1:
			fail("formal manifest should report %s, got: %s" % [expected_error, error_message])
			return
