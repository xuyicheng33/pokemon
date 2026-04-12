extends RefCounted
class_name ContentSnapshotCache

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const StorageScript := preload("res://src/battle_core/content/content_snapshot_cache_storage.gd")
const DependencyCollectorScript := preload("res://src/battle_core/content/content_snapshot_dependency_collector.gd")
const SignatureBuilderScript := preload("res://src/battle_core/content/content_snapshot_signature_builder.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var _storage = StorageScript.new()
var _dependency_collector = DependencyCollectorScript.new()
var _signature_builder = SignatureBuilderScript.new()
var _signature_static_file_paths := PackedStringArray([
	"res://config/formal_character_manifest.json",
	"res://config/formal_registry_contracts.json",
	"res://src/shared/formal_character_manifest.gd",
	"res://src/shared/formal_registry_contracts.gd",
])
var _signature_static_dir_paths := PackedStringArray([
	"res://src/battle_core/content",
	"res://src/battle_core/content/formal_validators",
	"res://src/shared/formal_character_manifest",
])
var signature_static_file_paths := PackedStringArray([
	"res://config/formal_character_manifest.json",
	"res://config/formal_registry_contracts.json",
	"res://src/shared/formal_character_manifest.gd",
	"res://src/shared/formal_registry_contracts.gd",
]):
	set(value):
		_signature_static_file_paths = value
		if _dependency_collector != null:
			_dependency_collector.signature_static_file_paths = value
	get:
		return _dependency_collector.signature_static_file_paths if _dependency_collector != null else _signature_static_file_paths
var signature_static_dir_paths := PackedStringArray([
	"res://src/battle_core/content",
	"res://src/battle_core/content/formal_validators",
	"res://src/shared/formal_character_manifest",
]):
	set(value):
		_signature_static_dir_paths = value
		if _dependency_collector != null:
			_dependency_collector.signature_static_dir_paths = value
	get:
		return _dependency_collector.signature_static_dir_paths if _dependency_collector != null else _signature_static_dir_paths

func _init() -> void:
	_signature_builder.dependency_collector = _dependency_collector
	_dependency_collector.signature_static_file_paths = _signature_static_file_paths
	_dependency_collector.signature_static_dir_paths = _signature_static_dir_paths

func build_content_index(content_snapshot_paths: PackedStringArray) -> Dictionary:
	_storage.begin_request()
	var signature := _signature_builder.build_signature(content_snapshot_paths)
	if signature.is_empty():
		return {
			"ok": false,
			"content_index": null,
			"cache_hit": false,
			"error_code": ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"error_message": "ContentSnapshotCache requires non-empty content_snapshot_paths",
		}
	var cached_result := _storage.load_resources(signature)
	if bool(cached_result.get("found", false)):
		return _build_index_result(cached_result.get("resources", []), false, true)
	var load_result: Dictionary = _load_validated_resources(content_snapshot_paths)
	if not bool(load_result.get("ok", false)):
		return load_result
	var validated_resources: Array = load_result.get("resources", [])
	_storage.store_resources(signature, validated_resources)
	return _build_index_result(_duplicate_resources(validated_resources), false, false)

func stats() -> Dictionary:
	return _storage.stats()

func clear() -> void:
	_storage.clear()

func _build_signature(content_snapshot_paths: PackedStringArray) -> String:
	return _signature_builder.build_signature(content_snapshot_paths)

func _load_validated_resources(content_snapshot_paths: PackedStringArray) -> Dictionary:
	var resources: Array = []
	for path in content_snapshot_paths:
		var resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			return {
				"ok": false,
				"content_index": null,
				"cache_hit": false,
				"error_code": ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
				"error_message": "Missing content resource: %s" % path,
			}
		resources.append(resource)
	return _build_index_result(resources, true, false, true)

func _build_index_result(resources: Array, run_validation: bool, cache_hit: bool, include_resources: bool = false) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_resources(resources, run_validation):
		var error_state: Dictionary = content_index.error_state()
		return {
			"ok": false,
			"content_index": null,
			"cache_hit": cache_hit,
			"error_code": error_state.get("code", ErrorCodesScript.INVALID_CONTENT_SNAPSHOT),
			"error_message": error_state.get("message", "ContentSnapshotCache failed to build content index"),
		}
	return {
		"ok": true,
		"content_index": content_index,
		"cache_hit": cache_hit,
		"resources": resources if include_resources else [],
		"error_code": null,
		"error_message": "",
	}

func _duplicate_resources(resources: Array) -> Array:
	var duplicates: Array = []
	for resource in resources:
		duplicates.append(resource.duplicate(true) if resource != null else null)
	return duplicates
