extends Resource
class_name PassiveItemDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var trigger_names: PackedStringArray = PackedStringArray()
@export var effect_ids: PackedStringArray = PackedStringArray()
@export var always_on_effect_ids: PackedStringArray = PackedStringArray()
@export var on_receive_effect_ids: PackedStringArray = PackedStringArray()
@export var on_turn_effect_ids: PackedStringArray = PackedStringArray()
