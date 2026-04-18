extends RefCounted
class_name ActionHitResolutionService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "hit_service",
		"source": "hit_service",
		"nested": true,
	},
	{
		"field": "rule_mod_service",
		"source": "rule_mod_service",
		"nested": true,
	},
	{
		"field": "rng_service",
		"source": "rng_service",
		"nested": true,
	},
]

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var hit_service
var rule_mod_service
var rng_service

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func resolve_hit(command, skill_definition, resolved_target, battle_state, content_index) -> Dictionary:
    if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT:
        return {"hit": true, "hit_roll": null}
    var resolved_accuracy: int = _resolve_base_accuracy(skill_definition)
    resolved_accuracy = _apply_field_accuracy_override(
        resolved_accuracy,
        command,
        skill_definition,
        resolved_target,
        battle_state,
        content_index
    )
    resolved_accuracy = _apply_incoming_accuracy_override(
        resolved_accuracy,
        command,
        skill_definition,
        resolved_target,
        battle_state
    )
    var hit_info: Dictionary = _roll_hit_result(resolved_accuracy)
    battle_state.rng_stream_index = rng_service.get_stream_index()
    return hit_info

func _resolve_base_accuracy(skill_definition) -> int:
    return int(skill_definition.accuracy)

func _apply_field_accuracy_override(base_accuracy: int, command, skill_definition, resolved_target, battle_state, content_index) -> int:
    if battle_state.field_state == null or command.actor_id != battle_state.field_state.creator:
        return base_accuracy
    var field_definition = content_index.fields.get(battle_state.field_state.field_def_id) if content_index != null else null
    if field_definition == null:
        return base_accuracy
    if int(field_definition.creator_accuracy_override) < 0:
        return base_accuracy
    if _should_nullify_field_accuracy(command, skill_definition, resolved_target, battle_state):
        return base_accuracy
    return int(field_definition.creator_accuracy_override)

func _apply_incoming_accuracy_override(base_accuracy: int, command, skill_definition, resolved_target, battle_state) -> int:
    if base_accuracy >= 100:
        return base_accuracy
    if not _should_read_incoming_accuracy(command, skill_definition, resolved_target, battle_state):
        return base_accuracy
    return rule_mod_service.resolve_incoming_accuracy(
        battle_state,
        resolved_target.unit_instance_id,
        base_accuracy
    )

func _roll_hit_result(resolved_accuracy: int) -> Dictionary:
    return hit_service.roll_hit(resolved_accuracy, rng_service)

func _should_nullify_field_accuracy(command, skill_definition, resolved_target, battle_state) -> bool:
    if not _should_read_incoming_accuracy(command, skill_definition, resolved_target, battle_state):
        return false
    return rule_mod_service.has_nullify_field_accuracy(
        battle_state,
        resolved_target.unit_instance_id
    )

func _should_read_incoming_accuracy(command, skill_definition, resolved_target, battle_state) -> bool:
    if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
        return false
    if skill_definition == null or String(skill_definition.targeting) != ContentSchemaScript.TARGET_ENEMY_ACTIVE:
        return false
    if resolved_target == null or resolved_target.leave_state != LeaveStatesScript.ACTIVE or resolved_target.current_hp <= 0:
        return false
    var actor_side = battle_state.get_side_for_unit(command.actor_id)
    var target_side = battle_state.get_side_for_unit(resolved_target.unit_instance_id)
    return actor_side != null and target_side != null and actor_side.side_id != target_side.side_id
