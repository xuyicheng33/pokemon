extends Resource
class_name SkillDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var damage_kind: String = "none"
@export var power: int = 0
@export var accuracy: int = 100
@export var mp_cost: int = 0
@export var priority: int = 0
@export var combat_type_id: String = ""
@export var power_bonus_source: String = ""
@export var power_bonus_self_effect_ids: PackedStringArray = PackedStringArray()
@export var power_bonus_target_effect_ids: PackedStringArray = PackedStringArray()
@export var power_bonus_per_stack: int = 0
@export var targeting: String = "enemy_active_slot"
@export var is_domain_skill: bool = false
@export var effects_on_cast_ids: PackedStringArray = PackedStringArray()
@export var effects_on_hit_ids: PackedStringArray = PackedStringArray()
@export var effects_on_miss_ids: PackedStringArray = PackedStringArray()
@export var effects_on_kill_ids: PackedStringArray = PackedStringArray()
