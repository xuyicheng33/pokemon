extends "res://tests/suites/content_validation_core/formal_registry/shared.gd"

const FormalCharacterCapabilityCatalogScript := preload("res://src/shared/formal_character_capability_catalog.gd")
const FieldCollectorScript := preload("res://tests/helpers/formal_capability_fact_collectors/field_collector.gd")
const PassiveCollectorScript := preload("res://tests/helpers/formal_capability_fact_collectors/passive_collector.gd")
const UnitCollectorScript := preload("res://tests/helpers/formal_capability_fact_collectors/unit_collector.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("formal_character_capability_catalog_manifest_alignment_contract", failures, Callable(self, "_test_formal_character_capability_catalog_manifest_alignment_contract").bind(harness))
	runner.run_test("formal_character_capability_collectors_cover_non_skill_effect_resources_contract", failures, Callable(self, "_test_formal_character_capability_collectors_cover_non_skill_effect_resources_contract").bind(harness))

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
	var observed_consumer_count: Dictionary = {}
	for raw_entry in catalog_result.get("data", []):
		var entry: Dictionary = raw_entry
		var capability_id := String(entry.get("capability_id", "")).strip_edges()
		var required_suite_paths: PackedStringArray = PackedStringArray(entry.get("required_suite_paths", []))
		var observed_consumers := 0
		for raw_delivery_entry in delivery_result.get("entries", []):
			var delivery_entry: Dictionary = raw_delivery_entry
			var character_id := String(delivery_entry.get("character_id", "")).strip_edges()
			var declared_capability_ids: PackedStringArray = manifest_capabilities_by_character.get(character_id, PackedStringArray())
			if declared_capability_ids.find(capability_id) == -1:
				continue
			observed_consumers += 1
			var required_suite_paths_actual: PackedStringArray = PackedStringArray(delivery_entry.get("required_suite_paths", []))
			for required_suite_path in required_suite_paths:
				if required_suite_paths_actual.find(required_suite_path) == -1:
					return harness.fail_result("manifest[%s] capability[%s] missing required suite: %s" % [
						character_id,
						capability_id,
							required_suite_path,
						])
		observed_consumer_count[capability_id] = observed_consumers
	for raw_entry in catalog_result.get("data", []):
		var entry: Dictionary = raw_entry
		var capability_id := String(entry.get("capability_id", "")).strip_edges()
		if int(observed_consumer_count.get(capability_id, 0)) <= 0:
			return harness.fail_result("capability catalog entry must have at least one manifest consumer: %s" % capability_id)
	return harness.pass_result()

func _test_formal_character_capability_collectors_cover_non_skill_effect_resources_contract(harness) -> Dictionary:
	var field_result := _collect_facts_result(
		FieldCollectorScript.new(),
		"content/fields/gojo/gojo_unlimited_void_field.tres",
		["field_creator_accuracy_override", "field_expire_effects", "field_break_effects"]
	)
	if not bool(field_result.get("ok", false)):
		return harness.fail_result(String(field_result.get("error_message", "field collector contract failed")))
	var passive_result := _collect_facts_result(
		PassiveCollectorScript.new(),
		"content/passive_skills/gojo/gojo_mugen.tres",
		["passive_trigger_binding", "passive_effect_binding"]
	)
	if not bool(passive_result.get("ok", false)):
		return harness.fail_result(String(passive_result.get("error_message", "passive collector contract failed")))
	var unit_result := _collect_facts_result(
		UnitCollectorScript.new(),
		"content/units/gojo/gojo_satoru.tres",
		["unit_passive_skill_binding", "unit_ultimate_skill_binding", "unit_candidate_skill_pool"]
	)
	if not bool(unit_result.get("ok", false)):
		return harness.fail_result(String(unit_result.get("error_message", "unit collector contract failed")))
	return harness.pass_result()

func _collect_facts_result(collector, rel_path: String, required_fact_ids: Array) -> Dictionary:
	var resource = load("res://%s" % rel_path)
	if resource == null:
		return harness_fail_result("missing resource for collector probe: %s" % rel_path)
	var fact_sources: Dictionary = {}
	collector.collect_resource_facts(fact_sources, rel_path, resource, Callable(self, "_register_fact"))
	for raw_fact_id in required_fact_ids:
		var fact_id := String(raw_fact_id).strip_edges()
		var sources: Array = fact_sources.get(fact_id, [])
		if not sources.has(rel_path):
			return harness_fail_result("collector probe missing fact %s for %s; got %s" % [fact_id, rel_path, fact_sources])
	return {
		"ok": true,
		"error_message": "",
	}

func _register_fact(fact_sources: Dictionary, fact_id: String, rel_path: String) -> void:
	var normalized_fact_id := String(fact_id).strip_edges()
	var normalized_rel_path := String(rel_path).strip_edges()
	if normalized_fact_id.is_empty() or normalized_rel_path.is_empty():
		return
	var sources: Array = fact_sources.get(normalized_fact_id, [])
	if sources.has(normalized_rel_path):
		return
	sources.append(normalized_rel_path)
	fact_sources[normalized_fact_id] = sources

func harness_fail_result(error_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_message": error_message,
	}
