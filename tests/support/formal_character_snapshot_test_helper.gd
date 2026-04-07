extends RefCounted
class_name FormalCharacterSnapshotTestHelper

const FormalCharacterSnapshotDescriptorHelperScript := preload("res://tests/support/formal_character_snapshot_descriptor_helper.gd")

var _descriptor_helper = FormalCharacterSnapshotDescriptorHelperScript.new()

func build_content_index(harness):
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return null
	return harness.build_loaded_content_index(sample_factory)

func build_content_index_for_setup(harness, battle_setup):
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return null
	return harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)

func append_unit_checks(checks: Array[Dictionary], unit_definition, descriptor: Dictionary) -> void:
	_descriptor_helper.append_unit_checks(checks, unit_definition, descriptor)

func append_skill_checks(checks: Array[Dictionary], skill_definition, descriptor: Dictionary) -> void:
	_descriptor_helper.append_skill_checks(checks, skill_definition, descriptor)

func append_passive_checks(checks: Array[Dictionary], passive_skill_definition, descriptor: Dictionary) -> void:
	_descriptor_helper.append_passive_checks(checks, passive_skill_definition, descriptor)

func append_effect_checks(checks: Array[Dictionary], effect_definition, descriptor: Dictionary) -> void:
	_descriptor_helper.append_effect_checks(checks, effect_definition, descriptor)

func append_field_checks(checks: Array[Dictionary], field_definition, descriptor: Dictionary) -> void:
	_descriptor_helper.append_field_checks(checks, field_definition, descriptor)

func run_checks(harness, checks: Array[Dictionary]) -> Dictionary:
	var failures: Array[String] = []
	for check in checks:
		if check["actual"] != check["expected"]:
			failures.append("%s expected=%s actual=%s" % [
				String(check["label"]),
				var_to_str(check["expected"]),
				var_to_str(check["actual"]),
			])
	if not failures.is_empty():
		return harness.fail_result("\n".join(failures))
	return harness.pass_result()

func run_descriptor_checks(harness, content_map: Dictionary, descriptors: Array, id_key: String, missing_message: String) -> Dictionary:
	var payload := build_descriptor_checks(content_map, descriptors, id_key)
	var missing_ids: Array[String] = payload.get("missing_ids", [])
	if not missing_ids.is_empty():
		return harness.fail_result("%s: %s" % [missing_message, var_to_str(missing_ids)])
	return run_checks(harness, payload.get("checks", []))

func build_descriptor_checks(content_map: Dictionary, descriptors: Array, id_key: String) -> Dictionary:
	return _descriptor_helper.build_descriptor_checks(content_map, descriptors, id_key)
