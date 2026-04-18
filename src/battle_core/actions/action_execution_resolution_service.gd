extends RefCounted
class_name ActionExecutionResolutionService

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
		"field": "action_skill_effect_service",
		"source": "action_skill_effect_service",
		"nested": true,
	},
]

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

var action_cast_service
var action_log_service
var action_skill_effect_service

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func resolve_started_action(queued_action, actor, command, skill_definition, battle_state, content_index, result) -> void:
    var resolved_target = action_cast_service.resolve_target(queued_action, battle_state)
    _update_chain_context_target(queued_action, battle_state, resolved_target)
    if not action_cast_service.is_action_target_valid(command, queued_action, resolved_target):
        action_log_service.log_action_failed_post_start(queued_action, battle_state, command)
        result.result_type = "action_failed_post_start"
        return
    var hit_info: Dictionary = action_cast_service.resolve_hit(command, skill_definition, resolved_target, battle_state, content_index)
    if not bool(hit_info["hit"]):
        _resolve_miss(queued_action, actor, command, skill_definition, resolved_target, hit_info, battle_state, content_index, result)
        return
    var action_hit_cause_event_id: String = action_log_service.log_action_hit(
        queued_action,
        battle_state,
        command,
        action_cast_service.resolve_target_instance_id(queued_action, resolved_target),
        hit_info["hit_roll"]
    )
    if action_cast_service.is_damage_action(command, skill_definition):
        var direct_damage_result: Dictionary = action_cast_service.apply_direct_damage(
            queued_action,
            actor,
            resolved_target,
            skill_definition,
            battle_state,
            content_index,
            action_hit_cause_event_id
        )
        if direct_damage_result.get("invalid_battle_code", null) != null:
            result.invalid_battle_code = direct_damage_result.get("invalid_battle_code", null)
            return
    _dispatch_on_receive_action_hit_if_needed(queued_action, command, resolved_target, battle_state, content_index, result)
    if result.invalid_battle_code != null:
        return
    if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT:
        action_cast_service.apply_default_recoil(queued_action, actor, battle_state, action_hit_cause_event_id)
    action_skill_effect_service.dispatch_trigger("on_hit", skill_definition, queued_action, actor, battle_state, content_index, result)
    if result.invalid_battle_code != null:
        return
    result.result_type = "resolved"

func _update_chain_context_target(queued_action, battle_state, resolved_target) -> void:
    if resolved_target == null:
        return
    if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
        return
    battle_state.chain_context.target_unit_id = resolved_target.unit_instance_id

func _resolve_miss(queued_action, actor, command, skill_definition, resolved_target, hit_info: Dictionary, battle_state, content_index, result) -> void:
    action_log_service.log_action_miss(
        queued_action,
        battle_state,
        command,
        action_cast_service.resolve_target_instance_id(queued_action, resolved_target),
        hit_info["hit_roll"]
    )
    action_skill_effect_service.dispatch_trigger("on_miss", skill_definition, queued_action, actor, battle_state, content_index, result)
    if result.invalid_battle_code != null:
        return
    result.result_type = "miss"

func _dispatch_on_receive_action_hit_if_needed(queued_action, command, resolved_target, battle_state, content_index, result) -> void:
    if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
        return
    if queued_action.target_snapshot.target_kind != ContentSchemaScript.TARGET_ENEMY_ACTIVE:
        return
    if resolved_target == null:
        return
    var actor_side = battle_state.get_side_for_unit(command.actor_id)
    var target_side = battle_state.get_side_for_unit(resolved_target.unit_instance_id)
    if actor_side == null or target_side == null or actor_side.side_id == target_side.side_id:
        return
    var invalid_code = action_cast_service.execute_lifecycle_trigger_batch(
        ContentSchemaScript.TRIGGER_ON_RECEIVE_ACTION_HIT,
        battle_state,
        content_index,
        [resolved_target.unit_instance_id]
    )
    if invalid_code != null:
        result.invalid_battle_code = invalid_code
