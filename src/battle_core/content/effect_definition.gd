extends Resource
class_name EffectDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var scope: String = "self"
@export var duration_mode: String = "permanent"
@export var duration: int = 0
@export var decrement_on: String = ""
@export var stacking: String = "none"
@export var max_stacks: int = -1
@export var priority: int = 0
@export var trigger_names: PackedStringArray = PackedStringArray()
@export var required_target_effects: PackedStringArray = PackedStringArray()
@export var on_expire_effect_ids: PackedStringArray = PackedStringArray()
@export var payloads: Array[Resource] = []
@export var persists_on_switch: bool = false
