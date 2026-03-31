extends RefCounted
class_name ActionCastService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const SOURCE_KIND_ORDER_ACTIVE_SKILL := 2

var mp_service
var damage_service
var combat_type_service
var stat_calculator
var rule_mod_service
var action_hit_resolution_service
var target_resolver
var trigger_dispatcher
var effect_queue_service
var payload_executor
var faint_resolver
var trigger_batch_runner
var rng_service
var action_log_service
var action_cast_direct_damage_pipeline
var action_cast_skill_effect_dispatch_pipeline

func resolve_missing_dependency() -> String:
    if mp_service == null:
        return "mp_service"
    if damage_service == null:
        return "damage_service"
    if combat_type_service == null:
        return "combat_type_service"
    if stat_calculator == null:
        return "stat_calculator"
    if rule_mod_service == null:
        return "rule_mod_service"
    if action_hit_resolution_service == null:
        return "action_hit_resolution_service"
    var hit_missing := str(action_hit_resolution_service.resolve_missing_dependency())
    if not hit_missing.is_empty():
        return "action_hit_resolution_service.%s" % hit_missing
    if target_resolver == null:
        return "target_resolver"
    if trigger_dispatcher == null:
        return "trigger_dispatcher"
    if effect_queue_service == null:
        return "effect_queue_service"
    if payload_executor == null:
        return "payload_executor"
    if faint_resolver == null:
        return "faint_resolver"
    if trigger_batch_runner == null:
        return "trigger_batch_runner"
    if rng_service == null:
        return "rng_service"
    if action_log_service == null:
        return "action_log_service"
    if action_cast_direct_damage_pipeline == null:
        return "action_cast_direct_damage_pipeline"
    var direct_pipeline_missing := str(action_cast_direct_damage_pipeline.resolve_missing_dependency())
    if not direct_pipeline_missing.is_empty():
        return "action_cast_direct_damage_pipeline.%s" % direct_pipeline_missing
    if action_cast_skill_effect_dispatch_pipeline == null:
        return "action_cast_skill_effect_dispatch_pipeline"
    var dispatch_pipeline_missing := str(action_cast_skill_effect_dispatch_pipeline.resolve_missing_dependency())
    if not dispatch_pipeline_missing.is_empty():
        return "action_cast_skill_effect_dispatch_pipeline.%s" % dispatch_pipeline_missing
    return ""

func resolve_mp_cost(command, skill_definition) -> int:
    if command.command_type == CommandTypesScript.SKILL or command.command_type == CommandTypesScript.ULTIMATE:
        return skill_definition.mp_cost
    return 0

func consume_mp(actor, consumed_mp: int) -> Array:
    var mp_changes: Array = []
    if consumed_mp > 0:
        var before_mp: int = actor.current_mp
        actor.current_mp = mp_service.consume_mp(actor.current_mp, consumed_mp)
        mp_changes.append(action_log_service.build_value_change(actor.unit_instance_id, "mp", before_mp, actor.current_mp))
    return mp_changes

func resolve_target(queued_action, battle_state):
    return target_resolver.resolve_target(queued_action, battle_state)

func is_action_target_valid(command, queued_action, resolved_target) -> bool:
    if command.command_type == CommandTypesScript.SWITCH:
        return true
    if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
        return true
    if resolved_target == null:
        return false
    return resolved_target.leave_state == LeaveStatesScript.ACTIVE and resolved_target.current_hp > 0

func resolve_target_instance_id(queued_action, resolved_target):
    if resolved_target == null:
        return null
    if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
        return null
    return resolved_target.unit_instance_id

func resolve_hit(command, skill_definition, resolved_target, battle_state, content_index) -> Dictionary:
    return action_hit_resolution_service.resolve_hit(
        command,
        skill_definition,
        resolved_target,
        battle_state,
        content_index
    )

func is_damage_action(command, skill_definition) -> bool:
    if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT:
        return true
    return skill_definition != null and skill_definition.damage_kind != ContentSchemaScript.DAMAGE_KIND_NONE and skill_definition.power > 0

func apply_direct_damage(queued_action, actor, target, skill_definition, battle_state, cause_event_id: String) -> void:
    action_cast_direct_damage_pipeline.apply_direct_damage(
        queued_action,
        actor,
        target,
        skill_definition,
        battle_state,
        cause_event_id,
        SOURCE_KIND_ORDER_ACTIVE_SKILL
    )

func apply_default_recoil(queued_action, actor, battle_state, cause_event_id: String) -> void:
    action_cast_direct_damage_pipeline.apply_default_recoil(
        queued_action,
        actor,
        battle_state,
        cause_event_id,
        SOURCE_KIND_ORDER_ACTIVE_SKILL
    )

func dispatch_skill_effects(effect_ids: PackedStringArray, trigger_name: String, queued_action, actor, battle_state, content_index, result) -> void:
    action_cast_skill_effect_dispatch_pipeline.dispatch_skill_effects(
        effect_ids,
        trigger_name,
        queued_action,
        actor,
        battle_state,
        content_index,
        result,
        SOURCE_KIND_ORDER_ACTIVE_SKILL
    )

func execute_lifecycle_trigger_batch(trigger_name: String, battle_state, content_index, owner_unit_ids: Array):
    return trigger_batch_runner.execute_trigger_batch(
        trigger_name,
        battle_state,
        content_index,
        owner_unit_ids,
        battle_state.chain_context
    )
