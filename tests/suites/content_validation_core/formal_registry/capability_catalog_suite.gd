extends "res://tests/suites/content_validation_core/formal_registry/shared.gd"

const FormalCharacterCapabilityCatalogScript := preload("res://src/shared/formal_character_capability_catalog.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("formal_character_capability_catalog_manifest_alignment_contract", failures, Callable(self, "_test_formal_character_capability_catalog_manifest_alignment_contract").bind(harness))

func _test_formal_character_capability_catalog_manifest_alignment_contract(harness) -> Dictionary:
	var catalog = FormalCharacterCapabilityCatalogScript.new()
	var catalog_result: Dictionary = catalog.load_entries_result()
	if not bool(catalog_result.get("ok", false)):
		return harness.fail_result("formal character capability catalog should load cleanly: %s" % String(catalog_result.get("error_message", "unknown error")))
	var delivery_registry := FormalCharacterRegistryScript.new()
	var delivery_result: Dictionary = delivery_registry.load_entries_result()
	if not bool(delivery_result.get("ok", false)):
		return harness.fail_result("formal delivery registry should load for capability alignment: %s" % String(delivery_result.get("error", "unknown error")))
	var manifest_capabilities_by_character: Dictionary = {}
	for raw_entry in delivery_result.get("entries", []):
		var entry: Dictionary = raw_entry
		manifest_capabilities_by_character[String(entry.get("character_id", "")).strip_edges()] = PackedStringArray(entry.get("shared_capability_ids", []))
	for raw_entry in catalog_result.get("data", []):
		var entry: Dictionary = raw_entry
		var capability_id := String(entry.get("capability_id", "")).strip_edges()
		var required_suite_paths: PackedStringArray = PackedStringArray(entry.get("required_suite_paths", []))
		for raw_character_id in entry.get("consumer_character_ids", []):
			var character_id := String(raw_character_id).strip_edges()
			if not manifest_capabilities_by_character.has(character_id):
				return harness.fail_result("capability catalog references unknown manifest character: %s" % character_id)
			var declared_capability_ids: PackedStringArray = manifest_capabilities_by_character.get(character_id, PackedStringArray())
			if declared_capability_ids.find(capability_id) == -1:
				return harness.fail_result("manifest[%s] missing shared_capability_id: %s" % [character_id, capability_id])
		for raw_delivery_entry in delivery_result.get("entries", []):
			var delivery_entry: Dictionary = raw_delivery_entry
			var character_id := String(delivery_entry.get("character_id", "")).strip_edges()
			var declared_capability_ids: PackedStringArray = manifest_capabilities_by_character.get(character_id, PackedStringArray())
			if declared_capability_ids.find(capability_id) == -1:
				continue
			var required_suite_paths_actual: PackedStringArray = PackedStringArray(delivery_entry.get("required_suite_paths", []))
			for required_suite_path in required_suite_paths:
				if required_suite_paths_actual.find(required_suite_path) == -1:
					return harness.fail_result("manifest[%s] capability[%s] missing required suite: %s" % [
						character_id,
						capability_id,
						required_suite_path,
					])
	return harness.pass_result()
