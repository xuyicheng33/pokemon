extends RefCounted
class_name CommandBuilder

const CommandScript := preload("res://src/battle_core/contracts/command.gd")

var id_factory

func build_command(input_payload: Dictionary):
    assert(input_payload.has("command_type"), "CommandBuilder requires command_type")
    assert(input_payload.has("side_id"), "CommandBuilder requires side_id")
    assert(input_payload.has("actor_id") or input_payload.has("actor_public_id"), "CommandBuilder requires actor_id or actor_public_id")
    var command = CommandScript.new()
    command.command_id = input_payload.get("command_id", id_factory.next_id("command"))
    command.turn_index = input_payload.get("turn_index", 1)
    command.command_type = input_payload.get("command_type", "")
    command.command_source = input_payload.get("command_source", "manual")
    command.side_id = input_payload.get("side_id", "")
    command.actor_id = input_payload.get("actor_id", "")
    command.actor_public_id = input_payload.get("actor_public_id", "")
    command.skill_id = input_payload.get("skill_id", "")
    command.target_unit_id = input_payload.get("target_unit_id", "")
    command.target_public_id = input_payload.get("target_public_id", "")
    command.target_slot = input_payload.get("target_slot", "")
    return command
