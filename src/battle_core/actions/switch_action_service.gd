extends RefCounted
class_name SwitchActionService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "action_cast_service",
		"source": "action_cast_service",
		"nested": true,
	},
	{
		"field": "action_log_service",
		"source": "action_log_service",
		"nested": true,
	},
	{
		"field": "replacement_service",
		"source": "replacement_service",
		"nested": true,
	},
]

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ActionResultScript := preload("res://src/battle_core/contracts/action_result.gd")

var action_cast_service
var action_log_service
var replacement_service

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func execute_switch_action(queued_action, battle_state, content_index) -> Variant:
    var result = ActionResultScript.new()
    var command = queued_action.command
    var side_state = battle_state.get_side(command.side_id)
    if side_state == null or not side_state.has_bench_unit(command.target_unit_id):
        result.result_type = "invalid_battle"
        result.invalid_battle_code = ErrorCodesScript.INVALID_SWITCH_TARGET_NOT_BENCH
        return result
    var actor = battle_state.get_unit(command.actor_id)
    var target_unit = battle_state.get_unit(command.target_unit_id)
    if actor == null or target_unit == null:
        result.result_type = "invalid_battle"
        result.invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return result
    action_log_service.log_switch_state(queued_action, battle_state, actor, target_unit)
    var replace_result: Dictionary = replacement_service.execute_replacement_lifecycle(
        battle_state,
        content_index,
        actor.unit_instance_id,
        command.target_unit_id,
        "manual_switch",
        action_cast_service.trigger_batch_executor()
    )
    var invalid_code = replace_result.get("invalid_code", null)
    if invalid_code != null:
        result.result_type = "invalid_battle"
        result.invalid_battle_code = invalid_code
        return result
    result.result_type = "resolved"
    return result
