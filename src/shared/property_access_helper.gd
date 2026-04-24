extends RefCounted
class_name PropertyAccessHelper

static func has_property(value, property_name: String) -> bool:
	if value == null or property_name.is_empty():
		return false
	if value is Dictionary:
		return value.has(property_name)
	if typeof(value) != TYPE_OBJECT:
		return false
	for property_info in value.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false

static func read_property(value, property_name: String, default_value = null) -> Variant:
	if value == null or property_name.is_empty():
		return default_value
	if value is Dictionary:
		return value.get(property_name, default_value)
	if typeof(value) != TYPE_OBJECT:
		return default_value
	if not has_property(value, property_name):
		return default_value
	return value.get(property_name)
