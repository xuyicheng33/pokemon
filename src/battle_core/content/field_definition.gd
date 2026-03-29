extends Resource
class_name FieldDefinition

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

@export var id: String = ""
@export var display_name: String = ""
@export var field_kind: String = ContentSchemaScript.FIELD_KIND_NORMAL
@export var effect_ids: PackedStringArray = PackedStringArray()
@export var on_expire_effect_ids: PackedStringArray = PackedStringArray()
@export var on_break_effect_ids: PackedStringArray = PackedStringArray()
@export var creator_accuracy_override: int = -1
