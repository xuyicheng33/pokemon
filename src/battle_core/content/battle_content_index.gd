extends RefCounted
class_name BattleContentIndex

const BattleContentRegistryScript := preload("res://src/battle_core/content/battle_content_registry.gd")
const ContentSnapshotValidatorScript := preload("res://src/battle_core/content/content_snapshot_validator.gd")
const BattleSetupValidatorScript := preload("res://src/battle_core/content/battle_setup_validator.gd")

var battle_formats: Dictionary = {}
var combat_types: Dictionary = {}
var units: Dictionary = {}
var skills: Dictionary = {}
var passive_skills: Dictionary = {}
var passive_items: Dictionary = {}
var effects: Dictionary = {}
var fields: Dictionary = {}
var duplicate_registration_errors: Array[String] = []

var _registry = BattleContentRegistryScript.new()
var _snapshot_validator = ContentSnapshotValidatorScript.new()
var _setup_validator = BattleSetupValidatorScript.new()

func clear() -> void:
    _registry.clear(self)

func load_snapshot(content_snapshot_paths: PackedStringArray) -> void:
    clear()
    for path in content_snapshot_paths:
        var resource = ResourceLoader.load(path, "", 0)
        assert(resource != null, "Missing content resource: %s" % path)
        _registry.register_resource(self, resource)
    var errors = validate_snapshot()
    assert(errors.is_empty(), "Content validation failed:\n%s" % "\n".join(errors))

func register_resource(resource: Resource) -> void:
    _registry.register_resource(self, resource)

func validate_snapshot() -> Array:
    return _snapshot_validator.validate(self)

func validate_setup(battle_setup) -> Array:
    return _setup_validator.validate(self, battle_setup)
