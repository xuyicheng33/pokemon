extends "res://src/battle_core/lifecycle/replacement_selector.gd"
class_name DefaultReplacementSelector

func select_replacement(_battle_state, _side_id: String, legal_bench_ids: PackedStringArray, _reason: String, _chain_context):
    if legal_bench_ids.is_empty():
        return null
    return legal_bench_ids[0]
