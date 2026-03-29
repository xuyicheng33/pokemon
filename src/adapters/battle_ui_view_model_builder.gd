extends RefCounted
class_name BattleUIViewModelBuilder

func build_view_model(public_snapshot: Dictionary) -> Dictionary:
    assert(public_snapshot != null, "BattleUIViewModelBuilder requires public snapshot")
    var side_models: Array = []
    for side_snapshot in public_snapshot.get("sides", []):
        side_models.append({
            "side_id": side_snapshot.get("side_id", ""),
            "active_public_id": side_snapshot.get("active_public_id", null),
            "active_hp": side_snapshot.get("active_hp", null),
            "active_mp": side_snapshot.get("active_mp", null),
            "active_ultimate_points": side_snapshot.get("active_ultimate_points", null),
            "active_ultimate_points_cap": side_snapshot.get("active_ultimate_points_cap", null),
            "active_ultimate_points_required": side_snapshot.get("active_ultimate_points_required", null),
            "bench_public_ids": side_snapshot.get("bench_public_ids", []),
        })
    return {
        "battle_id": public_snapshot.get("battle_id", ""),
        "turn_index": int(public_snapshot.get("turn_index", 0)),
        "phase": public_snapshot.get("phase", ""),
        "field_id": public_snapshot.get("field_id", null),
        "sides": side_models,
        "battle_result": public_snapshot.get("battle_result", null),
    }
