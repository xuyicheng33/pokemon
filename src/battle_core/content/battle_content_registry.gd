extends RefCounted
class_name BattleContentRegistry

const BattleFormatConfigScript := preload("res://src/battle_core/content/battle_format_config.gd")
const CombatTypeDefinitionScript := preload("res://src/battle_core/content/combat_type_definition.gd")
const UnitDefinitionScript := preload("res://src/battle_core/content/unit_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")

func clear(content_index) -> void:
    content_index.battle_formats.clear()
    content_index.combat_types.clear()
    content_index.units.clear()
    content_index.skills.clear()
    content_index.passive_skills.clear()
    content_index.passive_items.clear()
    content_index.effects.clear()
    content_index.fields.clear()
    content_index.duplicate_registration_errors.clear()

func register_resource(content_index, resource: Resource) -> void:
    if resource is BattleFormatConfigScript:
        _register_unique_resource(content_index.battle_formats, String(resource.format_id), resource, "battle_format", content_index.duplicate_registration_errors)
        return
    if resource is CombatTypeDefinitionScript:
        _register_unique_resource(content_index.combat_types, String(resource.id), resource, "combat_type", content_index.duplicate_registration_errors)
        return
    if resource is UnitDefinitionScript:
        _register_unique_resource(content_index.units, String(resource.id), resource, "unit", content_index.duplicate_registration_errors)
        return
    if resource is SkillDefinitionScript:
        _register_unique_resource(content_index.skills, String(resource.id), resource, "skill", content_index.duplicate_registration_errors)
        return
    if resource is PassiveSkillDefinitionScript:
        _register_unique_resource(content_index.passive_skills, String(resource.id), resource, "passive_skill", content_index.duplicate_registration_errors)
        return
    if resource is PassiveItemDefinitionScript:
        _register_unique_resource(content_index.passive_items, String(resource.id), resource, "passive_item", content_index.duplicate_registration_errors)
        return
    if resource is EffectDefinitionScript:
        _register_unique_resource(content_index.effects, String(resource.id), resource, "effect", content_index.duplicate_registration_errors)
        return
    if resource is FieldDefinitionScript:
        _register_unique_resource(content_index.fields, String(resource.id), resource, "field", content_index.duplicate_registration_errors)
        return
    assert(false, "Unsupported content resource: %s" % resource.resource_path)

func _register_unique_resource(store: Dictionary, raw_id: String, resource: Resource, label: String, duplicate_registration_errors: Array[String]) -> void:
    var normalized_id := raw_id.strip_edges()
    if normalized_id.is_empty():
        duplicate_registration_errors.append("%s id must not be empty" % label)
        return
    if store.has(normalized_id) and store[normalized_id] != resource:
        duplicate_registration_errors.append("%s duplicated id: %s" % [label, normalized_id])
        return
    store[normalized_id] = resource
