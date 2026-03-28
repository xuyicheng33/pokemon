extends Resource
class_name FieldDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var effect_ids: PackedStringArray = PackedStringArray()
@export var on_expire_effect_ids: PackedStringArray = PackedStringArray()
@export var on_break_effect_ids: PackedStringArray = PackedStringArray()
@export var creator_accuracy_override: int = -1
