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

var last_error_message: String = ""

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
	last_error_message = ""

func register_resource(content_index, resource: Resource) -> bool:
	last_error_message = ""
	if resource is BattleFormatConfigScript:
		return _register_unique_resource(content_index.battle_formats, String(resource.format_id), resource, "battle_format", content_index.duplicate_registration_errors)
	if resource is CombatTypeDefinitionScript:
		return _register_unique_resource(content_index.combat_types, String(resource.id), resource, "combat_type", content_index.duplicate_registration_errors)
	if resource is UnitDefinitionScript:
		return _register_unique_resource(content_index.units, String(resource.id), resource, "unit", content_index.duplicate_registration_errors)
	if resource is SkillDefinitionScript:
		return _register_unique_resource(content_index.skills, String(resource.id), resource, "skill", content_index.duplicate_registration_errors)
	if resource is PassiveSkillDefinitionScript:
		return _register_unique_resource(content_index.passive_skills, String(resource.id), resource, "passive_skill", content_index.duplicate_registration_errors)
	if resource is PassiveItemDefinitionScript:
		return _register_unique_resource(content_index.passive_items, String(resource.id), resource, "passive_item", content_index.duplicate_registration_errors)
	if resource is EffectDefinitionScript:
		return _register_unique_resource(content_index.effects, String(resource.id), resource, "effect", content_index.duplicate_registration_errors)
	if resource is FieldDefinitionScript:
		return _register_unique_resource(content_index.fields, String(resource.id), resource, "field", content_index.duplicate_registration_errors)
	var resource_label := resource.resource_path if resource != null and not String(resource.resource_path).is_empty() else "<memory:%s>" % resource
	last_error_message = "unsupported content resource: %s" % resource_label
	content_index.duplicate_registration_errors.append(last_error_message)
	return false

func _register_unique_resource(store: Dictionary, raw_id: String, resource: Resource, label: String, duplicate_registration_errors: Array[String]) -> bool:
	var normalized_id := raw_id.strip_edges()
	if normalized_id.is_empty():
		duplicate_registration_errors.append("%s id must not be empty" % label)
		return false
	if store.has(normalized_id) and store[normalized_id] != resource:
		duplicate_registration_errors.append("%s duplicated id: %s" % [label, normalized_id])
		return false
	store[normalized_id] = resource
	return true
