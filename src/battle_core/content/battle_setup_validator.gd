extends RefCounted
class_name BattleSetupValidator

var _content_index = null

func validate(content_index, battle_setup) -> Array:
    _content_index = content_index
    var errors: Array = []
    if battle_setup == null:
        errors.append("battle_setup missing")
        _content_index = null
        return errors
    var format_definition = _content_index.battle_formats.get(String(battle_setup.format_id).strip_edges(), null)
    if format_definition == null:
        errors.append("battle_setup.format_id missing battle format: %s" % String(battle_setup.format_id))
    for side_setup in battle_setup.sides:
        var side_id: String = str(side_setup.side_id)
        var seen_unit_definition_ids: Dictionary = {}
        var seen_passive_items: Dictionary = {}
        for raw_unit_definition_id in side_setup.unit_definition_ids:
            var unit_definition_id := str(raw_unit_definition_id).strip_edges()
            if unit_definition_id.is_empty():
                continue
            if seen_unit_definition_ids.has(unit_definition_id):
                errors.append("battle_setup.side[%s] duplicated unit_definition_id: %s" % [side_id, unit_definition_id])
                continue
            seen_unit_definition_ids[unit_definition_id] = true
            if not _content_index.units.has(unit_definition_id):
                continue
            var unit_definition = _content_index.units[unit_definition_id]
            var passive_item_id := str(unit_definition.passive_item_id)
            if passive_item_id.is_empty():
                continue
            if seen_passive_items.has(passive_item_id):
                errors.append("battle_setup.side[%s] duplicated passive_item_id: %s" % [side_id, passive_item_id])
                continue
            seen_passive_items[passive_item_id] = true
        _validate_regular_skill_loadout_overrides(errors, side_setup, format_definition)
    _content_index = null
    return errors

func _validate_regular_skill_loadout_overrides(errors: Array, side_setup, format_definition) -> void:
    var side_id: String = str(side_setup.side_id)
    if typeof(side_setup.regular_skill_loadout_overrides) != TYPE_DICTIONARY:
        errors.append("battle_setup.side[%s].regular_skill_loadout_overrides must be Dictionary" % side_id)
        return
    var team_size: int = side_setup.unit_definition_ids.size()
    if format_definition != null:
        team_size = int(format_definition.team_size)
    for raw_slot_index in side_setup.regular_skill_loadout_overrides.keys():
        if typeof(raw_slot_index) != TYPE_INT:
            errors.append("battle_setup.side[%s].regular_skill_loadout_overrides key must be slot index int: %s" % [side_id, str(raw_slot_index)])
            continue
        var slot_index: int = int(raw_slot_index)
        if slot_index < 0 or slot_index >= team_size or slot_index >= side_setup.unit_definition_ids.size():
            errors.append("battle_setup.side[%s].regular_skill_loadout_overrides slot out of range: %d" % [side_id, slot_index])
            continue
        var loadout = side_setup.regular_skill_loadout_overrides[raw_slot_index]
        if typeof(loadout) != TYPE_PACKED_STRING_ARRAY:
            errors.append("battle_setup.side[%s].regular_skill_loadout_overrides[%d] must be PackedStringArray" % [side_id, slot_index])
            continue
        if loadout.size() != 3:
            errors.append("battle_setup.side[%s].regular_skill_loadout_overrides[%d] must contain exactly 3 skills, got %d" % [side_id, slot_index, loadout.size()])
        var seen_skills: Dictionary = {}
        for skill_id in loadout:
            var normalized_skill_id := String(skill_id).strip_edges()
            if seen_skills.has(normalized_skill_id):
                errors.append("battle_setup.side[%s].regular_skill_loadout_overrides[%d] duplicated skill: %s" % [side_id, slot_index, normalized_skill_id])
                continue
            seen_skills[normalized_skill_id] = true
        var unit_definition_id := str(side_setup.unit_definition_ids[slot_index])
        var unit_definition = _content_index.units.get(unit_definition_id, null)
        if unit_definition == null:
            continue
        if unit_definition.candidate_skill_ids.is_empty():
            if loadout != unit_definition.skill_ids:
                errors.append("battle_setup.side[%s].regular_skill_loadout_overrides[%d] must equal default skill_ids when candidate_skill_ids is empty" % [side_id, slot_index])
            continue
        for skill_id in loadout:
            var normalized_skill_id := String(skill_id).strip_edges()
            if not unit_definition.candidate_skill_ids.has(normalized_skill_id):
                errors.append("battle_setup.side[%s].regular_skill_loadout_overrides[%d] skill not in candidate_skill_ids: %s" % [side_id, slot_index, normalized_skill_id])
