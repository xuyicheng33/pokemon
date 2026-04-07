extends RefCounted
class_name SampleBattleFactoryOverrideRouter

var baseline_matchup_catalog
var content_paths_helper
var demo_catalog
var delivery_registry_loader
var formal_matchup_catalog
var runtime_registry_loader

func configure_registry_path_override(path: String) -> void:
	_broadcast_shared_registry_override(path)
	formal_matchup_catalog.runtime_registry_path_override = path

func configure_baseline_matchup_catalog_path_override(path: String) -> void:
	baseline_matchup_catalog.catalog_path_override = path
	refresh_baseline_unit_definition_ids()

func configure_matchup_catalog_path_override(path: String) -> void:
	formal_matchup_catalog.catalog_path_override = path
	_broadcast_shared_registry_override(path)

func configure_delivery_registry_path_override(path: String) -> void:
	_broadcast_shared_registry_override(path)
	formal_matchup_catalog.runtime_registry_path_override = path
	formal_matchup_catalog.catalog_path_override = path

func configure_formal_manifest_path_override(path: String) -> void:
	_broadcast_shared_registry_override(path)
	formal_matchup_catalog.runtime_registry_path_override = path
	formal_matchup_catalog.catalog_path_override = path

func configure_demo_catalog_path_override(path: String) -> void:
	demo_catalog.catalog_path_override = path

func refresh_baseline_unit_definition_ids() -> void:
	var baseline_units_result: Dictionary = baseline_matchup_catalog.baseline_unit_definition_ids_result()
	content_paths_helper.baseline_unit_definition_ids = baseline_units_result.get("data", PackedStringArray()) if bool(baseline_units_result.get("ok", false)) else PackedStringArray()

func _broadcast_shared_registry_override(path: String) -> void:
	runtime_registry_loader.registry_path_override = path
	content_paths_helper.registry_path_override = path
	delivery_registry_loader.registry_path_override = path
