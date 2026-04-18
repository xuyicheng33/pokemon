extends RefCounted
class_name IdFactory

var _counter: int = 0

func reset(start_from: int = 0) -> void:
	_counter = start_from

func next_id(prefix: String) -> String:
	_counter += 1
	return "%s_%d" % [prefix, _counter]
