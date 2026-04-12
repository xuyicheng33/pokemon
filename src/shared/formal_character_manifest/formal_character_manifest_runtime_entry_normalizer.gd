extends RefCounted
class_name FormalCharacterManifestRuntimeEntryNormalizer

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ManifestLoaderScript := preload("res://src/shared/formal_character_manifest/formal_character_manifest_loader.gd")
const FormalRegistryContractsScript := preload("res://src/shared/formal_registry_contracts.gd")

const REQUIRED_BENCH_UNIT_COUNT := 2

var _registry_contracts = FormalRegistryContractsScript.new()

func normalize_entry_result(entry: Dictionary, character_id: String) -> Dictionary:
	for raw_rel_path in entry.get("required_content_paths", []):
		if String(raw_rel_path).strip_edges().is_empty():
			return _error_result("FormalCharacterManifest[%s] has empty required_content_paths entry" % character_id)
	var baseline_script_path_result := _normalize_script_path_result(
		String(entry.get("baseline_script_path", "")).strip_edges(),
		"baseline script",
		character_id
	)
	if not bool(baseline_script_path_result.get("ok", false)):
		return baseline_script_path_result
	entry["baseline_script_path"] = String(baseline_script_path_result.get("data", "")).strip_edges()
	for field_name in ["pair_initiator_bench_unit_ids", "pair_responder_bench_unit_ids"]:
		var normalized_bench_units_result := _normalize_bench_unit_ids_result(
			entry.get(field_name, null),
			character_id,
			field_name
		)
		if not bool(normalized_bench_units_result.get("ok", false)):
			return normalized_bench_units_result
		entry[field_name] = normalized_bench_units_result.get("data", []).duplicate(true)
	var owned_pair_specs_result := _normalize_owned_pair_interaction_specs_result(
		entry.get("owned_pair_interaction_specs", null),
		character_id
	)
	if not bool(owned_pair_specs_result.get("ok", false)):
		return owned_pair_specs_result
	entry["owned_pair_interaction_specs"] = owned_pair_specs_result.get("data", []).duplicate(true)
	var validator_path := String(entry.get("content_validator_script_path", "")).strip_edges()
	if not validator_path.is_empty():
		var validator_path_result := _normalize_script_path_result(validator_path, "validator", character_id)
		if not bool(validator_path_result.get("ok", false)):
			return validator_path_result
		entry["content_validator_script_path"] = String(validator_path_result.get("data", "")).strip_edges()
	return _ok_result(entry)

func _normalize_bench_unit_ids_result(raw_bench_unit_ids, character_id: String, field_name: String) -> Dictionary:
	if not (raw_bench_unit_ids is Array):
		return _error_result("FormalCharacterManifest[%s].%s must be array" % [character_id, field_name])
	if raw_bench_unit_ids.size() != REQUIRED_BENCH_UNIT_COUNT:
		return _error_result(
			"FormalCharacterManifest[%s].%s must contain exactly %d unit ids" % [character_id, field_name, REQUIRED_BENCH_UNIT_COUNT]
		)
	var normalized_bench_unit_ids: Array = []
	var seen_unit_definition_ids: Dictionary = {}
	for raw_unit_definition_id in raw_bench_unit_ids:
		var unit_definition_id := String(raw_unit_definition_id).strip_edges()
		if unit_definition_id.is_empty() or seen_unit_definition_ids.has(unit_definition_id):
			return _error_result(
				"FormalCharacterManifest[%s].%s must contain distinct non-empty unit ids" % [character_id, field_name]
			)
		seen_unit_definition_ids[unit_definition_id] = true
		normalized_bench_unit_ids.append(unit_definition_id)
	return _ok_result(normalized_bench_unit_ids)

func _normalize_owned_pair_interaction_specs_result(raw_specs, character_id: String) -> Dictionary:
	if not (raw_specs is Array):
		return _error_result("FormalCharacterManifest[%s].owned_pair_interaction_specs must be array" % character_id)
	var normalized_specs: Array = []
	var seen_other_character_ids: Dictionary = {}
	for spec_index in range(raw_specs.size()):
		var raw_spec = raw_specs[spec_index]
		if not (raw_spec is Dictionary):
			return _error_result(
				"FormalCharacterManifest[%s].owned_pair_interaction_specs[%d] must be dictionary" % [character_id, spec_index]
			)
		var spec: Dictionary = raw_spec.duplicate(true)
		var field_result := _registry_contracts.validate_required_fields_result(
			FormalRegistryContractsScript.OWNED_PAIR_INTERACTION_SPEC_BUCKET,
			spec,
			"FormalCharacterManifest[%s].owned_pair_interaction_specs[%d]" % [character_id, spec_index]
		)
		if not bool(field_result.get("ok", false)):
			return field_result
		var other_character_id := String(spec.get("other_character_id", "")).strip_edges()
		if other_character_id == character_id:
			return _error_result(
				"FormalCharacterManifest[%s].owned_pair_interaction_specs[%d] must not target self" % [character_id, spec_index]
			)
		if seen_other_character_ids.has(other_character_id):
			return _error_result(
				"FormalCharacterManifest[%s] duplicated owned pair interaction target: %s" % [character_id, other_character_id]
			)
		seen_other_character_ids[other_character_id] = true
		normalized_specs.append(spec)
	return _ok_result(normalized_specs)

func _normalize_script_path_result(raw_script_path: String, label: String, character_id: String) -> Dictionary:
	var resolved_script_path := ManifestLoaderScript.normalize_resource_path(raw_script_path)
	if resolved_script_path.is_empty() or not ResourceLoader.exists(resolved_script_path):
		return _error_result(
			"FormalCharacterManifest[%s] missing %s: %s" % [
				character_id,
				label,
				resolved_script_path if not resolved_script_path.is_empty() else raw_script_path,
			]
		)
	var script = load(resolved_script_path)
	if not (script is Script) or not script.can_instantiate():
		return _error_result(
			"FormalCharacterManifest[%s] %s is not instantiable: %s" % [character_id, label, resolved_script_path]
		)
	return _ok_result(resolved_script_path)

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
