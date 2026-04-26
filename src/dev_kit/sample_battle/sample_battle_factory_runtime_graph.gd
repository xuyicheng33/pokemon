extends RefCounted
class_name SampleBattleFactoryRuntimeGraph

const AvailableMatchupAggregatorScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_available_matchup_aggregator.gd")
const BaselineLoaderScript := preload("res://src/shared/formal_character_baselines/formal_character_baseline_loader.gd")
const BaselineMatchupCatalogScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_baseline_matchup_catalog.gd")
const CatalogFacadeScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_catalog_facade.gd")
const ContentPathsHelperScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_content_paths_helper.gd")
const DemoCatalogScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_demo_catalog.gd")
const DemoFacadeScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_demo_facade.gd")
const DemoInputBuilderScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_demo_input_builder.gd")
const FormalAccessScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_formal_access.gd")
const MatchupCatalogScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_matchup_catalog.gd")
const SetupAccessScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_setup_access.gd")
const SetupFacadeScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_setup_facade.gd")
const SnapshotFacadeScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory_snapshot_facade.gd")

const OVERRIDE_REGISTRY_PATH := "registry_path_override"
const OVERRIDE_BASELINE_MATCHUP_CATALOG_PATH := "baseline_matchup_catalog_path_override"
const OVERRIDE_FORMAL_MATCHUP_CATALOG_PATH := "formal_matchup_catalog_path_override"
const OVERRIDE_DEMO_CATALOG_PATH := "demo_catalog_path_override"

var override_config: Dictionary = {
	OVERRIDE_REGISTRY_PATH: "",
	OVERRIDE_BASELINE_MATCHUP_CATALOG_PATH: "",
	OVERRIDE_FORMAL_MATCHUP_CATALOG_PATH: "",
	OVERRIDE_DEMO_CATALOG_PATH: "",
}
var catalog_access: SampleBattleFactoryBaselineMatchupCatalog = BaselineMatchupCatalogScript.new()
var snapshot_access: SampleBattleFactoryContentPathsHelper = ContentPathsHelperScript.new()
var demo_input_builder: SampleBattleFactoryDemoInputBuilder = DemoInputBuilderScript.new()
var demo_catalog: SampleBattleFactoryDemoCatalog = DemoCatalogScript.new()
var formal_access: SampleBattleFactoryFormalAccess = FormalAccessScript.new()
var formal_matchup_catalog: SampleBattleFactoryFormalMatchupCatalog = MatchupCatalogScript.new()
var setup_access: SampleBattleFactorySetupAccess = SetupAccessScript.new()
var available_matchup_aggregator: SampleBattleFactoryAvailableMatchupAggregator = AvailableMatchupAggregatorScript.new()
var setup_facade: SampleBattleFactorySetupFacade = SetupFacadeScript.new()
var demo_facade: SampleBattleFactoryDemoFacade = DemoFacadeScript.new()
var catalog_facade: SampleBattleFactoryCatalogFacade = CatalogFacadeScript.new()
var snapshot_facade: SampleBattleFactorySnapshotFacade = SnapshotFacadeScript.new()

func _init() -> void:
	_bind_override_config()
	_wire_access_services()
	_wire_facades()
	BaselineLoaderScript.invalidate_cache()

func configure_registry_path_override(path: String) -> void:
	override_config[OVERRIDE_REGISTRY_PATH] = path

func configure_baseline_matchup_catalog_path_override(path: String) -> void:
	override_config[OVERRIDE_BASELINE_MATCHUP_CATALOG_PATH] = path
	catalog_access.refresh_baseline_unit_definition_ids()

func configure_matchup_catalog_path_override(path: String) -> void:
	override_config[OVERRIDE_FORMAL_MATCHUP_CATALOG_PATH] = path

func configure_demo_catalog_path_override(path: String) -> void:
	override_config[OVERRIDE_DEMO_CATALOG_PATH] = path

func dispose() -> void:
	_nullify_links(setup_access, ["baseline_matchup_catalog", "formal_matchup_catalog"])
	_nullify_links(snapshot_access, ["formal_access"])
	_nullify_links(demo_input_builder, ["baseline_matchup_catalog", "content_paths_helper", "demo_catalog", "setup_access"])
	_nullify_links(formal_access, ["formal_matchup_catalog", "setup_access"])
	_nullify_links(catalog_access, ["snapshot_access", "demo_catalog"])
	_nullify_links(available_matchup_aggregator, ["baseline_matchup_catalog", "formal_matchup_catalog"])
	_nullify_links(setup_facade, ["setup_access", "formal_access"])
	_nullify_links(demo_facade, ["demo_catalog", "demo_input_builder"])
	_nullify_links(catalog_facade, ["available_matchup_aggregator", "formal_access"])
	_nullify_links(snapshot_facade, ["content_paths_helper"])
	_nullify_override_config([catalog_access, snapshot_access, demo_catalog, formal_access, formal_matchup_catalog])

func _bind_override_config() -> void:
	catalog_access.override_config = override_config
	snapshot_access.override_config = override_config
	demo_catalog.override_config = override_config
	formal_access.override_config = override_config
	formal_matchup_catalog.override_config = override_config

func _wire_access_services() -> void:
	setup_access.baseline_matchup_catalog = catalog_access
	setup_access.formal_matchup_catalog = formal_matchup_catalog
	snapshot_access.formal_access = formal_access
	demo_input_builder.baseline_matchup_catalog = catalog_access
	demo_input_builder.content_paths_helper = snapshot_access
	demo_input_builder.demo_catalog = demo_catalog
	demo_input_builder.setup_access = setup_access
	formal_access.formal_matchup_catalog = formal_matchup_catalog
	formal_access.setup_access = setup_access
	catalog_access.snapshot_access = snapshot_access
	catalog_access.demo_catalog = demo_catalog
	catalog_access.refresh_baseline_unit_definition_ids()
	available_matchup_aggregator.baseline_matchup_catalog = catalog_access
	available_matchup_aggregator.formal_matchup_catalog = formal_matchup_catalog

func _wire_facades() -> void:
	setup_facade.setup_access = setup_access
	setup_facade.formal_access = formal_access
	demo_facade.demo_catalog = demo_catalog
	demo_facade.demo_input_builder = demo_input_builder
	catalog_facade.available_matchup_aggregator = available_matchup_aggregator
	catalog_facade.formal_access = formal_access
	snapshot_facade.content_paths_helper = snapshot_access

static func _nullify_links(target, property_names: Array) -> void:
	if target == null:
		return
	for prop_name in property_names:
		target.set(prop_name, null)

static func _nullify_override_config(targets: Array) -> void:
	for target in targets:
		if target != null:
			target.override_config = {}
