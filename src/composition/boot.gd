extends Node
class_name Boot

func _ready() -> void:
    call_deferred("_open_sandbox")

func _open_sandbox() -> void:
    get_tree().change_scene_to_file("res://scenes/sandbox/BattleSandbox.tscn")
