extends RefCounted
class_name SelectionState

var selected_command = null
var selection_locked: bool = false
var timed_out: bool = false

func to_stable_dict() -> Dictionary:
    return {
        "selected_command": selected_command.to_stable_dict() if selected_command != null else null,
        "selection_locked": selection_locked,
        "timed_out": timed_out,
    }
