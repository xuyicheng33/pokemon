extends Resource
class_name UnitDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var base_hp: int = 0
@export var base_attack: int = 0
@export var base_defense: int = 0
@export var base_sp_attack: int = 0
@export var base_sp_defense: int = 0
@export var base_speed: int = 0
@export var skill_ids: PackedStringArray = PackedStringArray()
@export var passive_skill_id: String = ""
@export var passive_item_id: String = ""
