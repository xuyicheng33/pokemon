extends RefCounted
class_name ContentSnapshotCatalogValidator

const CombatTypeChartEntryScript := preload("res://src/battle_core/content/combat_type_chart_entry.gd")

func validate(content_index, errors: Array) -> void:
    var allowed_chart_multipliers: Array[float] = [2.0, 1.0, 0.5]
    for combat_type_id in content_index.combat_types.keys():
        var combat_type_definition = content_index.combat_types[combat_type_id]
        if String(combat_type_definition.display_name).strip_edges().is_empty():
            errors.append("combat_type[%s].display_name must not be empty" % combat_type_id)

    for format_id in content_index.battle_formats.keys():
        var format_definition = content_index.battle_formats[format_id]
        if String(format_definition.visibility_mode).strip_edges().is_empty():
            errors.append("battle_format[%s].visibility_mode must not be empty" % format_id)
        if float(format_definition.default_recoil_ratio) < 0.0 or float(format_definition.default_recoil_ratio) > 1.0:
            errors.append("battle_format[%s].default_recoil_ratio out of range: %s" % [format_id, float(format_definition.default_recoil_ratio)])
        if float(format_definition.domain_clash_tie_threshold) < 0.0 or float(format_definition.domain_clash_tie_threshold) > 1.0:
            errors.append("battle_format[%s].domain_clash_tie_threshold out of range: %s" % [format_id, float(format_definition.domain_clash_tie_threshold)])
        var seen_chart_pairs: Dictionary = {}
        for chart_entry in format_definition.combat_type_chart:
            if chart_entry == null:
                errors.append("battle_format[%s].combat_type_chart contains null" % format_id)
                continue
            if not chart_entry is CombatTypeChartEntryScript:
                errors.append("battle_format[%s].combat_type_chart invalid type: %s" % [format_id, chart_entry])
                continue
            var attacker_type_id := String(chart_entry.atk).strip_edges()
            var defender_type_id := String(chart_entry.def).strip_edges()
            var multiplier := float(chart_entry.mul)
            if attacker_type_id.is_empty():
                errors.append("battle_format[%s].combat_type_chart missing atk" % format_id)
            elif not content_index.combat_types.has(attacker_type_id):
                errors.append("battle_format[%s].combat_type_chart unknown atk: %s" % [format_id, attacker_type_id])
            if defender_type_id.is_empty():
                errors.append("battle_format[%s].combat_type_chart missing def" % format_id)
            elif not content_index.combat_types.has(defender_type_id):
                errors.append("battle_format[%s].combat_type_chart unknown def: %s" % [format_id, defender_type_id])
            if not allowed_chart_multipliers.has(multiplier):
                errors.append("battle_format[%s].combat_type_chart invalid mul: %s" % [format_id, multiplier])
            if attacker_type_id.is_empty() or defender_type_id.is_empty():
                continue
            var chart_pair_key := "%s|%s" % [attacker_type_id, defender_type_id]
            if seen_chart_pairs.has(chart_pair_key):
                errors.append("battle_format[%s].combat_type_chart duplicated pair: %s" % [format_id, chart_pair_key])
                continue
            seen_chart_pairs[chart_pair_key] = true
