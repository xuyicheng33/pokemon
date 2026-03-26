extends RefCounted
class_name BattleCoreSession

var session_id: String = ""
var container = null
var battle_state = null
var content_index = null

func dispose() -> void:
    if container != null and container.has_method("dispose"):
        container.dispose()
    container = null
    battle_state = null
    content_index = null
