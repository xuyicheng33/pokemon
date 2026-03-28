extends "res://src/battle_core/content/effect_payload.gd"
class_name RuleModPayload

@export var mod_kind: String = "final_mod"
@export var mod_op: String = ""
@export var value: Variant = null
@export var scope: String = "self"
@export var duration_mode: String = "permanent"
@export var duration: int = 0
@export var decrement_on: String = ""
@export var stacking: String = "none"
@export var priority: int = 0
@export var dynamic_value_formula: String = ""
@export var dynamic_value_thresholds: PackedInt32Array = PackedInt32Array()
@export var dynamic_value_outputs: PackedFloat32Array = PackedFloat32Array()
@export var dynamic_value_default: float = 0.0
