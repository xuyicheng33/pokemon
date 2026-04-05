extends RefCounted
class_name PayloadUnitTargetHelper

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

func resolve_target_unit(scope: String, effect_event, battle_state) -> Variant:
    match scope:
        "self":
            return battle_state.get_unit(effect_event.owner_id)
        "target":
            if effect_event.chain_context == null or effect_event.chain_context.target_unit_id == null:
                return null
            return battle_state.get_unit(str(effect_event.chain_context.target_unit_id))
        "action_actor":
            if effect_event.chain_context == null or effect_event.chain_context.action_actor_id == null:
                return null
            return battle_state.get_unit(str(effect_event.chain_context.action_actor_id))
        _:
            return null

func is_effect_target_valid(target_unit, scope: String = "", effect_event = null) -> bool:
    if target_unit == null:
        return false
    if _allows_on_receive_action_hit_target(scope, effect_event):
        return true
    if target_unit.current_hp <= 0:
        return false
    if _allows_inactive_field_owner_target(scope, effect_event):
        return true
    return target_unit.leave_state == LeaveStatesScript.ACTIVE

func _allows_inactive_field_owner_target(scope: String, effect_event) -> bool:
    if scope != "self" or effect_event == null:
        return false
    return effect_event.trigger_name == "field_break" or effect_event.trigger_name == "field_expire"

func _allows_on_receive_action_hit_target(scope: String, effect_event) -> bool:
    if effect_event == null or effect_event.trigger_name != "on_receive_action_hit":
        return false
    return scope == "self" or scope == "action_actor"
