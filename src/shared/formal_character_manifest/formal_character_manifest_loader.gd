extends RefCounted
class_name FormalCharacterManifestLoader

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const FormalRegistryContractsScript := preload("res://src/shared/formal_registry_contracts.gd")
const ResourcePathHelperScript := preload("res://src/shared/resource_path_helper.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

const DEFAULT_MANIFEST_PATH := "res://config/formal_character_manifest.json"
const CHARACTERS_BUCKET := "characters"
const MATCHUPS_BUCKET := "matchups"
const REQUIRED_BENCH_UNIT_COUNT := 2

var _registry_contracts = FormalRegistryContractsScript.new()

func load_manifest_payload_result(manifest_path: String, manifest_path_override: String = "") -> Dictionary:
	var resolved_manifest_path := resolve_manifest_path(manifest_path, manifest_path_override)
	var file := FileAccess.open(resolved_manifest_path, FileAccess.READ)
	if file == null:
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest missing manifest: %s" % resolved_manifest_path
		)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest expects top-level dictionary: %s" % resolved_manifest_path
		)
	if parsed.has("pair_surface_cases"):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest no longer accepts pair_surface_cases: %s" % resolved_manifest_path
		)
	var characters = parsed.get(CHARACTERS_BUCKET, null)
	if not (characters is Array):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest[%s] must be array: %s" % [CHARACTERS_BUCKET, resolved_manifest_path]
		)
	var matchups = parsed.get(MATCHUPS_BUCKET, null)
	if not (matchups is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest[%s] must be dictionary: %s" % [MATCHUPS_BUCKET, resolved_manifest_path]
		)
	if parsed.has("pair_interaction_cases"):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest no longer accepts pair_interaction_cases: %s" % resolved_manifest_path
		)
	if parsed.has("pair_interaction_specs"):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest no longer accepts pair_interaction_specs: %s" % resolved_manifest_path
		)
	return _ok_result({
		CHARACTERS_BUCKET: characters.duplicate(true),
		MATCHUPS_BUCKET: matchups.duplicate(true),
	})

func resolve_manifest_path(manifest_path: String, manifest_path_override: String = "") -> String:
	var normalized_path := ResourcePathHelperScript.normalize(manifest_path)
	if not normalized_path.is_empty():
		return normalized_path
	return ResourcePathHelperScript.resolve(manifest_path_override, DEFAULT_MANIFEST_PATH)

static func normalize_resource_path(raw_path: String) -> String:
	return ResourcePathHelperScript.normalize(raw_path)

func normalize_entry_result(entry: Dictionary, character_id: String) -> Dictionary:
	for raw_rel_path in entry.get("required_content_paths", []):
		if String(raw_rel_path).strip_edges().is_empty():
			return _normalize_error_result("FormalCharacterManifest[%s] has empty required_content_paths entry" % character_id)
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
		return _normalize_error_result("FormalCharacterManifest[%s].%s must be array" % [character_id, field_name])
	if raw_bench_unit_ids.size() != REQUIRED_BENCH_UNIT_COUNT:
		return _normalize_error_result(
			"FormalCharacterManifest[%s].%s must contain exactly %d unit ids" % [character_id, field_name, REQUIRED_BENCH_UNIT_COUNT]
		)
	var normalized_bench_unit_ids: Array = []
	var seen_unit_definition_ids: Dictionary = {}
	for raw_unit_definition_id in raw_bench_unit_ids:
		var unit_definition_id := String(raw_unit_definition_id).strip_edges()
		if unit_definition_id.is_empty() or seen_unit_definition_ids.has(unit_definition_id):
			return _normalize_error_result(
				"FormalCharacterManifest[%s].%s must contain distinct non-empty unit ids" % [character_id, field_name]
			)
		seen_unit_definition_ids[unit_definition_id] = true
		normalized_bench_unit_ids.append(unit_definition_id)
	return _ok_result(normalized_bench_unit_ids)

func _normalize_owned_pair_interaction_specs_result(raw_specs, character_id: String) -> Dictionary:
	if not (raw_specs is Array):
		return _normalize_error_result("FormalCharacterManifest[%s].owned_pair_interaction_specs must be array" % character_id)
	var normalized_specs: Array = []
	var seen_other_character_ids: Dictionary = {}
	for spec_index in range(raw_specs.size()):
		var raw_spec = raw_specs[spec_index]
		if not (raw_spec is Dictionary):
			return _normalize_error_result(
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
			return _normalize_error_result(
				"FormalCharacterManifest[%s].owned_pair_interaction_specs[%d] must not target self" % [character_id, spec_index]
			)
		if seen_other_character_ids.has(other_character_id):
			return _normalize_error_result(
				"FormalCharacterManifest[%s] duplicated owned pair interaction target: %s" % [character_id, other_character_id]
			)
		seen_other_character_ids[other_character_id] = true
		normalized_specs.append(spec)
	return _ok_result(normalized_specs)

func _normalize_script_path_result(raw_script_path: String, label: String, character_id: String) -> Dictionary:
	var resolved_script_path := normalize_resource_path(raw_script_path)
	if resolved_script_path.is_empty() or not ResourceLoader.exists(resolved_script_path):
		return _normalize_error_result(
			"FormalCharacterManifest[%s] missing %s: %s" % [
				character_id,
				label,
				resolved_script_path if not resolved_script_path.is_empty() else raw_script_path,
			]
		)
	var script = load(resolved_script_path)
	if not (script is Script) or not script.can_instantiate():
		return _normalize_error_result(
			"FormalCharacterManifest[%s] %s is not instantiable: %s" % [character_id, label, resolved_script_path]
		)
	return _ok_result(resolved_script_path)

func _ok_result(data) -> Dictionary:
	return ResultEnvelopeHelperScript.ok(data)

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)

func _normalize_error_result(error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(ErrorCodesScript.INVALID_BATTLE_SETUP, error_message)
