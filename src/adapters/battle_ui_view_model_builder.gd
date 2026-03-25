extends RefCounted
class_name BattleUIViewModelBuilder

func build_view_model(battle_state) -> Dictionary:
    var side_models: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        side_models.append({
            "side_id": side_state.side_id,
            "active_public_id": active_unit.public_id if active_unit != null else null,
            "active_hp": active_unit.current_hp if active_unit != null else null,
            "active_mp": active_unit.current_mp if active_unit != null else null,
            "bench_order": side_state.bench_order,
        })
    return {
        "battle_id": battle_state.battle_id,
        "turn_index": battle_state.turn_index,
        "phase": battle_state.phase,
        "field_id": battle_state.field_state.field_def_id if battle_state.field_state != null else null,
        "sides": side_models,
        "battle_result": battle_state.battle_result.to_stable_dict() if battle_state.battle_result != null else null,
    }
