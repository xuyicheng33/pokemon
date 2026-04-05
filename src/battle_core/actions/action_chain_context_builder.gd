extends RefCounted
class_name ActionChainContextBuilder

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")

func build_chain_context(queued_action, battle_state, skill_definition) -> Variant:
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = queued_action.action_id
    chain_context.root_action_id = queued_action.action_id
    chain_context.chain_origin = "action"
    chain_context.action_queue_index = queued_action.queue_index
    chain_context.actor_id = queued_action.command.actor_id
    chain_context.command_type = queued_action.command.command_type
    chain_context.command_source = queued_action.command.command_source
    chain_context.skill_id = queued_action.command.skill_id if _uses_skill_definition(queued_action.command.command_type) else null
    chain_context.select_timeout = queued_action.command.command_source == "timeout_auto"
    chain_context.select_deadline_ms = battle_state.selection_deadline_ms
    chain_context.target_unit_id = queued_action.target_snapshot.target_unit_id
    chain_context.target_slot = queued_action.target_snapshot.target_slot
    chain_context.action_actor_id = queued_action.command.actor_id
    chain_context.action_combat_type_id = String(skill_definition.combat_type_id) if skill_definition != null and skill_definition.combat_type_id != null else ""
    chain_context.defer_field_apply_success = queued_action.defer_domain_success_effects
    return chain_context

func _uses_skill_definition(command_type: String) -> bool:
    return command_type == CommandTypesScript.SKILL or command_type == CommandTypesScript.ULTIMATE
