extends RefCounted
class_name ValueChangeFactory

const ValueChangeScript := preload("res://src/battle_core/contracts/value_change.gd")

static func create(entity_id_value: String, resource_name_value: String, before_value_value: int, after_value_value: int):
	var value_change = ValueChangeScript.new()
	value_change.entity_id = entity_id_value
	value_change.resource_name = resource_name_value
	value_change.before_value = before_value_value
	value_change.after_value = after_value_value
	value_change.delta = after_value_value - before_value_value
	return value_change
