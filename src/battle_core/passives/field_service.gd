extends RefCounted
class_name FieldService

func tick_turn_end(field_state) -> bool:
    if field_state == null:
        return false
    field_state.remaining_turns -= 1
    return field_state.remaining_turns <= 0
