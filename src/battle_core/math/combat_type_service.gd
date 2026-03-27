extends RefCounted
class_name CombatTypeService

var _chart: Dictionary = {}

func build_chart(chart_entries: Array) -> void:
    _chart.clear()
    for entry in chart_entries:
        if entry == null:
            continue
        var key := _build_key(String(entry.atk), String(entry.def))
        _chart[key] = float(entry.mul)

func calc_effectiveness(skill_type_id: String, defender_type_ids: PackedStringArray) -> float:
    if skill_type_id.is_empty() or defender_type_ids.is_empty():
        return 1.0
    var result: float = 1.0
    for defender_type_id in defender_type_ids:
        var key := _build_key(skill_type_id, String(defender_type_id))
        result *= float(_chart.get(key, 1.0))
    return result

func _build_key(attacker_type_id: String, defender_type_id: String) -> String:
    return "%s|%s" % [attacker_type_id, defender_type_id]
