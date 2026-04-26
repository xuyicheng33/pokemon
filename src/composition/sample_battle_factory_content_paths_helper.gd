extends RefCounted
class_name SampleBattleFactoryContentPathsHelper

const BattleInputContractHelperScript := preload("res://src/battle_core/contracts/battle_input_contract_helper.gd")
const BaseSnapshotPathsServiceScript := preload("res://src/composition/sample_battle_factory_base_snapshot_paths_service.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const BASE_CONTENT_SNAPSHOT_DIRS = BaseSnapshotPathsServiceScript.BASE_CONTENT_SNAPSHOT_DIRS
const PropertyAccessHelperScript := preload("res://src/shared/property_access_helper.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const OVERRIDE_REGISTRY_PATH := "registry_path_override"

var registry_path_override: String = ""
var override_config: Dictionary = {}
var baseline_unit_definition_ids: PackedStringArray = PackedStringArray()
var formal_access: SampleBattleFactoryFormalAccess = null
var _base_snapshot_paths_service: SampleBattleFactoryBaseSnapshotPathsService = BaseSnapshotPathsServiceScript.new()

func build_snapshot_paths(base_dirs: Array) -> Dictionary:
	var base_result := _base_snapshot_paths_service.build_base_snapshot_paths(base_dirs)
	if not bool(base_result.get("ok", false)):
		return base_result
	return _append_formal_snapshot_paths_result(
		base_result.get("data", PackedStringArray()),
		{},
		false
	)

func build_base_snapshot_paths(base_dirs: Array) -> Dictionary:
	return _base_snapshot_paths_service.build_base_snapshot_paths(base_dirs)

func build_snapshot_paths_for_setup(base_dirs: Array, battle_setup) -> Dictionary:
	if battle_setup == null:
		return _error_result(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"SampleBattleFactory requires battle_setup to build setup-scoped content snapshot paths"
		)
	var battle_setup_error := BattleInputContractHelperScript.validate_battle_setup_error(
		battle_setup,
		"SampleBattleFactory.content_snapshot_paths_for_setup_result"
	)
	if not battle_setup_error.is_empty():
		return _error_result(ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, battle_setup_error)
	var unit_definition_ids_result := _collect_unit_definition_ids_result(battle_setup)
	if not bool(unit_definition_ids_result.get("ok", false)):
		return unit_definition_ids_result
	var base_result := _base_snapshot_paths_service.build_base_snapshot_paths(base_dirs)
	if not bool(base_result.get("ok", false)):
		return base_result
	if _included_units_are_baseline_only(unit_definition_ids_result.get("data", {})):
		return ResultEnvelopeHelperScript.ok(base_result.get("data", PackedStringArray()))
	return _append_formal_snapshot_paths_result(
		base_result.get("data", PackedStringArray()),
		unit_definition_ids_result.get("data", {}),
		true
	)

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	return _base_snapshot_paths_service.collect_tres_paths_result(dir_path)

func collect_tres_paths_recursive(dir_path: String) -> Array[String]:
	var result := collect_tres_paths_recursive_result(dir_path)
	if not bool(result.get("ok", false)):
		return []
	return result.get("data", [])

func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary:
	return _base_snapshot_paths_service.collect_tres_paths_recursive_result(dir_path)

func _append_formal_snapshot_paths_result(
	base_paths,
	included_unit_definition_ids: Dictionary,
	restrict_registry_entries: bool
) -> Dictionary:
	var paths: Array[String] = []
	var seen: Dictionary = {}
	_base_snapshot_paths_service.append_unique_paths(paths, seen, base_paths)
	var registry_result: Dictionary = _load_runtime_entries_for_snapshot_result()
	if not bool(registry_result.get("ok", false)):
		return registry_result
	for raw_entry in registry_result.get("data", []):
		if not (raw_entry is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
				"SampleBattleFactory formal character runtime registry entry must be Dictionary"
			)
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var unit_definition_id := String(entry.get("unit_definition_id", "")).strip_edges()
		if restrict_registry_entries and not included_unit_definition_ids.has(unit_definition_id):
			continue
		var required_content_paths = entry.get("required_content_paths", [])
		if not (required_content_paths is Array):
			return _error_result(
				ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
				"SampleBattleFactory registry[%s] missing required_content_paths" % character_id
			)
		for raw_rel_path in required_content_paths:
			var resource_path := _base_snapshot_paths_service.normalize_res_path(String(raw_rel_path))
			if resource_path.is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
					"SampleBattleFactory registry[%s] has empty required_content_paths entry" % character_id
				)
			if not ResourceLoader.exists(resource_path):
				return _error_result(
					ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
					"SampleBattleFactory missing content snapshot resource: %s" % resource_path
				)
			_base_snapshot_paths_service.append_unique_path(paths, seen, resource_path)
	paths.sort()
	return ResultEnvelopeHelperScript.ok(PackedStringArray(paths))

func _collect_unit_definition_ids_result(battle_setup) -> Dictionary:
	var unit_definition_ids: Dictionary = {}
	var sides = _read_property(battle_setup, "sides", [])
	for side_index in range(sides.size()):
		var side_setup = sides[side_index]
		if side_setup == null:
			continue
		if not _has_property(side_setup, "unit_definition_ids"):
			return _error_result(
				ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
				"SampleBattleFactory.content_snapshot_paths_for_setup_result requires battle_setup.sides[%d].unit_definition_ids" % side_index
			)
		var raw_unit_definition_ids = _read_property(side_setup, "unit_definition_ids", null)
		if typeof(raw_unit_definition_ids) != TYPE_PACKED_STRING_ARRAY and typeof(raw_unit_definition_ids) != TYPE_ARRAY:
			return _error_result(
				ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
				"SampleBattleFactory.content_snapshot_paths_for_setup_result requires battle_setup.sides[%d].unit_definition_ids to be Array-like" % side_index
			)
		for raw_unit_definition_id in raw_unit_definition_ids:
			var unit_definition_id := String(raw_unit_definition_id).strip_edges()
			if unit_definition_id.is_empty():
				continue
			unit_definition_ids[unit_definition_id] = true
	return ResultEnvelopeHelperScript.ok(unit_definition_ids)

func _included_units_are_baseline_only(included_unit_definition_ids: Dictionary) -> bool:
	if included_unit_definition_ids.is_empty():
		return true
	var baseline_lookup: Dictionary = {}
	for raw_unit_definition_id in baseline_unit_definition_ids:
		baseline_lookup[String(raw_unit_definition_id)] = true
	if baseline_lookup.is_empty():
		return false
	for raw_unit_definition_id in included_unit_definition_ids.keys():
		if not baseline_lookup.has(String(raw_unit_definition_id)):
			return false
	return true

func _load_runtime_entries_for_snapshot_result() -> Dictionary:
	if formal_access == null:
		return _error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory content snapshot helper requires formal_access"
		)
	if formal_access.override_config.is_empty():
		formal_access.registry_path_override = _registry_path_override()
	return formal_access.load_runtime_entries_for_snapshot_result()

func _registry_path_override() -> String:
	if override_config.has(OVERRIDE_REGISTRY_PATH):
		var path := String(override_config.get(OVERRIDE_REGISTRY_PATH, "")).strip_edges()
		if not path.is_empty():
			return path
	return String(registry_path_override).strip_edges()

func _has_property(value, property_name: String) -> bool:
	return PropertyAccessHelperScript.has_property(value, property_name)

func _read_property(value, property_name: String, default_value = null) -> Variant:
	return PropertyAccessHelperScript.read_property(value, property_name, default_value)

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)
