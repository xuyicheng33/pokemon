extends RefCounted
class_name DeepCopyHelper

static func copy_value(value):
	if value == null:
		return null
	match typeof(value):
		TYPE_DICTIONARY:
			var copied_dictionary: Dictionary = {}
			for key in value.keys():
				copied_dictionary[key] = copy_value(value[key])
			return copied_dictionary
		TYPE_ARRAY:
			var copied_array: Array = []
			for element in value:
				copied_array.append(copy_value(element))
			return copied_array
		TYPE_PACKED_BYTE_ARRAY, \
		TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, \
		TYPE_PACKED_VECTOR3_ARRAY, \
		TYPE_PACKED_COLOR_ARRAY:
			return value.duplicate()
		_:
			return value
