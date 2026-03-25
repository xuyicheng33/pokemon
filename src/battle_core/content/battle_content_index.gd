extends RefCounted
class_name BattleContentIndex

const BattleFormatConfigScript := preload("res://src/battle_core/content/battle_format_config.gd")
const UnitDefinitionScript := preload("res://src/battle_core/content/unit_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")

var battle_formats: Dictionary = {}
var units: Dictionary = {}
var skills: Dictionary = {}
var passive_skills: Dictionary = {}
var passive_items: Dictionary = {}
var effects: Dictionary = {}
var fields: Dictionary = {}

func clear() -> void:
    battle_formats.clear()
    units.clear()
    skills.clear()
    passive_skills.clear()
    passive_items.clear()
    effects.clear()
    fields.clear()

func load_snapshot(content_snapshot_paths: PackedStringArray) -> void:
    clear()
    for path in content_snapshot_paths:
        var resource = load(path)
        assert(resource != null, "Missing content resource: %s" % path)
        register_resource(resource)

func register_resource(resource: Resource) -> void:
    if resource is BattleFormatConfigScript:
        battle_formats[resource.format_id] = resource
        return
    if resource is UnitDefinitionScript:
        units[resource.id] = resource
        return
    if resource is SkillDefinitionScript:
        skills[resource.id] = resource
        return
    if resource is PassiveSkillDefinitionScript:
        passive_skills[resource.id] = resource
        return
    if resource is PassiveItemDefinitionScript:
        passive_items[resource.id] = resource
        return
    if resource is EffectDefinitionScript:
        effects[resource.id] = resource
        return
    if resource is FieldDefinitionScript:
        fields[resource.id] = resource
        return
    assert(false, "Unsupported content resource: %s" % resource.resource_path)
