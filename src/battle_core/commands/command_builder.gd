extends RefCounted
class_name CommandBuilder

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "id_factory",
		"source": "id_factory",
		"nested": true,
	},
]

const CommandScript := preload("res://src/battle_core/contracts/command.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var id_factory
var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
    return {
        "code": last_error_code,
        "message": last_error_message,
    }

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func build_command(input_payload: Dictionary) -> Variant:
    last_error_code = null
    last_error_message = ""
    if id_factory == null:
        last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        last_error_message = "CommandBuilder missing id_factory"
        return null
    if not input_payload.has("command_type"):
        return _fail_invalid_payload("CommandBuilder requires command_type")
    if not input_payload.has("side_id"):
        return _fail_invalid_payload("CommandBuilder requires side_id")
    if not input_payload.has("actor_id") and not input_payload.has("actor_public_id"):
        return _fail_invalid_payload("CommandBuilder requires actor_id or actor_public_id")
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

func _fail_invalid_payload(message: String) -> Variant:
    last_error_code = ErrorCodesScript.INVALID_COMMAND_PAYLOAD
    last_error_message = message
    return null
