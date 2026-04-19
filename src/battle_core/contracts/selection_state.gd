extends RefCounted
class_name SelectionState

var selected_command: Command = null
var selection_locked: bool = false
var timed_out: bool = false

func to_stable_dict() -> Dictionary:
	var selected_command_dict: Variant = null
	if selected_command != null:
		selected_command_dict = selected_command.to_stable_dict()
	return {
		"selected_command": selected_command_dict,
		"selection_locked": selection_locked,
		"timed_out": timed_out,
	}
