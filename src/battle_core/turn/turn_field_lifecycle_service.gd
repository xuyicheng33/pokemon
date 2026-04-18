extends RefCounted
class_name TurnFieldLifecycleService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "field_service",
		"source": "field_service",
		"nested": true,
	},
	{
		"field": "trigger_batch_runner",
		"source": "trigger_batch_runner",
		"nested": true,
	},
	{
		"field": "battle_logger",
		"source": "battle_logger",
		"nested": true,
	},
	{
		"field": "log_event_builder",
		"source": "log_event_builder",
		"nested": true,
	},
	{
		"field": "battle_result_service",
		"source": "battle_result_service",
		"nested": true,
	},
]

const EventTypesScript := preload("res://src/shared/event_types.gd")
const FieldChangeScript := preload("res://src/battle_core/contracts/field_change.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var field_service
var trigger_batch_runner
var battle_logger
var log_event_builder
var battle_result_service

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func collect_active_unit_ids(battle_state) -> Array:
    var owner_ids: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit != null and active_unit.current_hp > 0:
            owner_ids.append(active_unit.unit_instance_id)
    return owner_ids

func execute_matchup_changed_if_needed(battle_state, content_index) -> bool:
    var signature: String = field_service.build_matchup_signature(battle_state)
    if signature.is_empty() or signature == battle_state.last_matchup_signature:
        return false
    var invalid_code = trigger_batch_runner.execute_trigger_batch(
        "on_matchup_changed",
        battle_state,
        content_index,
        collect_active_unit_ids(battle_state),
        battle_state.chain_context
    )
    if invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(invalid_code))
        return true
    battle_state.last_matchup_signature = signature
    return false

func break_field_if_creator_inactive(battle_state, content_index) -> bool:
    var invalid_code = field_service.break_field_if_creator_inactive(
        battle_state,
        content_index,
        battle_state.chain_context,
        Callable(trigger_batch_runner, "execute_trigger_batch")
    )
    if invalid_code == null:
        return false
    battle_result_service.terminate_invalid_battle(battle_state, str(invalid_code))
    return true

func break_active_field(battle_state, content_index, trigger_name: String) -> bool:
    var invalid_code = field_service.break_active_field(
        battle_state,
        content_index,
        trigger_name,
        battle_state.chain_context,
        Callable(trigger_batch_runner, "execute_trigger_batch")
    )
    if invalid_code == null:
        return false
    battle_result_service.terminate_invalid_battle(battle_state, str(invalid_code))
    return true

func apply_turn_end_field_tick(battle_state, content_index, cause_event_id: String) -> Variant:
    if battle_state.field_state == null:
        return {
            "field_change": null,
            "terminated": false,
        }
    var current_field_state = battle_state.field_state
    var field_definition = field_service.get_field_definition_for_state(current_field_state, content_index)
    if field_definition == null:
        battle_result_service.terminate_invalid_battle(battle_state, ErrorCodesScript.INVALID_STATE_CORRUPTION)
        return {
            "field_change": null,
            "terminated": true,
        }
    var field_change = FieldChangeScript.new()
    field_change.change_kind = "tick"
    field_change.before_field_id = current_field_state.field_def_id
    field_change.before_remaining_turns = current_field_state.remaining_turns
    var expired: bool = field_service.tick_turn_end(current_field_state)
    field_change.after_field_id = current_field_state.field_def_id if not expired else null
    field_change.after_remaining_turns = current_field_state.remaining_turns if not expired else 0
    if not expired:
        return {
            "field_change": field_change,
            "terminated": false,
        }
    if field_definition != null and not field_definition.on_expire_effect_ids.is_empty():
        var expire_events: Array = field_service.collect_lifecycle_effect_events(
            "field_expire",
            current_field_state,
            field_definition.on_expire_effect_ids,
            battle_state,
            content_index,
            battle_state.chain_context
        )
        if not expire_events.is_empty():
            var expire_invalid_code = trigger_batch_runner.execute_trigger_batch(
                "__field_expire__",
                battle_state,
                content_index,
                [],
                battle_state.chain_context,
                expire_events
            )
            if expire_invalid_code != null:
                battle_result_service.terminate_invalid_battle(battle_state, str(expire_invalid_code))
                return {
                    "field_change": field_change,
                    "terminated": true,
                }
    var active_field = battle_state.field_state
    if active_field == null:
        field_change.after_field_id = null
        field_change.after_remaining_turns = 0
    elif String(active_field.instance_id) != String(current_field_state.instance_id):
        field_change.after_field_id = active_field.field_def_id
        field_change.after_remaining_turns = active_field.remaining_turns
    var log_event = log_event_builder.build_effect_event(
        EventTypesScript.EFFECT_FIELD_EXPIRE,
        battle_state,
        cause_event_id,
        {
            "source_instance_id": current_field_state.instance_id,
            "trigger_name": "turn_end",
            "field_change": field_change,
            "payload_summary": "field expired",
        }
    )
    battle_logger.append_event(log_event)
    field_service.clear_field_state_if_matches(battle_state, current_field_state)
    return {
        "field_change": field_change,
        "terminated": false,
    }
