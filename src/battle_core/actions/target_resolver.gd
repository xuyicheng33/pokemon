extends RefCounted
class_name TargetResolver

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

func resolve_target(queued_action, battle_state):
    if queued_action.command.command_type == CommandTypesScript.SWITCH:
        return battle_state.get_unit(queued_action.command.target_unit_id)
    match queued_action.target_snapshot.target_kind:
        ContentSchemaScript.TARGET_ENEMY_ACTIVE:
            var opponent_side = battle_state.get_opponent_side(queued_action.command.side_id)
            if opponent_side == null:
                return null
            return opponent_side.get_active_unit(str(queued_action.target_snapshot.target_slot))
        ContentSchemaScript.TARGET_SELF:
            return battle_state.get_unit(queued_action.command.actor_id)
        ContentSchemaScript.TARGET_FIELD:
            return battle_state.field_state
        ContentSchemaScript.TARGET_NONE:
            return null
        _:
            return null
