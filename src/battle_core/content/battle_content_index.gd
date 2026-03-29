extends RefCounted
class_name BattleContentIndex

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const BattleContentRegistryScript := preload("res://src/battle_core/content/battle_content_registry.gd")
const ContentSnapshotValidatorScript := preload("res://src/battle_core/content/content_snapshot_validator.gd")
const BattleSetupValidatorScript := preload("res://src/battle_core/content/battle_setup_validator.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")

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

func is_domain_skill(skill_id: String) -> bool:
    var skill_definition = skills.get(skill_id, null)
    if skill_definition == null:
        return false
    return bool(skill_definition.is_domain_skill) or skill_applies_domain_field(skill_id)

func skill_applies_domain_field(skill_id: String) -> bool:
    var visited_effect_ids: Dictionary = {}
    var skill_definition = skills.get(skill_id, null)
    if skill_definition == null:
        return false
    var skill_effect_ids := PackedStringArray()
    skill_effect_ids.append_array(skill_definition.effects_on_cast_ids)
    skill_effect_ids.append_array(skill_definition.effects_on_hit_ids)
    skill_effect_ids.append_array(skill_definition.effects_on_miss_ids)
    skill_effect_ids.append_array(skill_definition.effects_on_kill_ids)
    for effect_id in skill_effect_ids:
        if _effect_applies_domain_field(String(effect_id), visited_effect_ids):
            return true
    return false

func _effect_applies_domain_field(effect_id: String, visited_effect_ids: Dictionary) -> bool:
    if effect_id.is_empty() or visited_effect_ids.has(effect_id):
        return false
    visited_effect_ids[effect_id] = true
    var effect_definition = effects.get(effect_id, null)
    if effect_definition == null:
        return false
    for payload in effect_definition.payloads:
        if payload is ApplyFieldPayloadScript:
            var field_definition = fields.get(String(payload.field_definition_id), null)
            if field_definition != null and String(field_definition.field_kind) == ContentSchemaScript.FIELD_KIND_DOMAIN:
                return true
            continue
        if payload is ApplyEffectPayloadScript and _effect_applies_domain_field(String(payload.effect_definition_id), visited_effect_ids):
            return true
    return false
