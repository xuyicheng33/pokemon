extends RefCounted
class_name BattleInitializerStateBuilder

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const SideStateScript := preload("res://src/battle_core/runtime/side_state.gd")
const SelectionStateScript := preload("res://src/battle_core/contracts/selection_state.gd")
const UnitStateScript := preload("res://src/battle_core/runtime/unit_state.gd")

func build_side_state(side_setup, format_config, content_index, id_factory, public_id_allocator):
    assert(side_setup != null, "BattleInitializerStateBuilder requires side_setup")
    assert(format_config != null, "BattleInitializerStateBuilder requires format_config")
    assert(content_index != null, "BattleInitializerStateBuilder requires content_index")
    assert(id_factory != null, "BattleInitializerStateBuilder requires id_factory")
    assert(public_id_allocator != null, "BattleInitializerStateBuilder requires public_id_allocator")
    assert(side_setup.unit_definition_ids.size() == format_config.team_size, "Side %s must provide exactly %d units" % [side_setup.side_id, format_config.team_size])
    assert(side_setup.starting_index >= 0 and side_setup.starting_index < side_setup.unit_definition_ids.size(), "Invalid starting index for %s" % side_setup.side_id)
    var side_state = SideStateScript.new()
    side_state.side_id = side_setup.side_id
    side_state.selection_state = SelectionStateScript.new()
    for unit_index in range(side_setup.unit_definition_ids.size()):
        var unit_definition_id = side_setup.unit_definition_ids[unit_index]
        var unit_definition = content_index.units.get(unit_definition_id)
        assert(unit_definition != null, "Missing unit definition: %s" % unit_definition_id)
        var unit_state = UnitStateScript.new()
        unit_state.unit_instance_id = id_factory.next_id("unit")
        unit_state.public_id = public_id_allocator.build_public_id(side_setup.side_id, unit_index)
        unit_state.definition_id = unit_definition.id
        unit_state.display_name = unit_definition.display_name
        unit_state.max_hp = unit_definition.base_hp
        unit_state.current_hp = unit_definition.base_hp
        unit_state.max_mp = unit_definition.max_mp
        unit_state.current_mp = unit_definition.init_mp
        unit_state.regen_per_turn = unit_definition.regen_per_turn
        unit_state.ultimate_points = 0
        unit_state.ultimate_points_cap = unit_definition.ultimate_points_cap
        unit_state.ultimate_points_required = unit_definition.ultimate_points_required
        unit_state.ultimate_point_gain_on_regular_skill_cast = unit_definition.ultimate_point_gain_on_regular_skill_cast
        unit_state.regular_skill_ids = _resolve_regular_skill_loadout(side_setup, unit_index, unit_definition)
        unit_state.combat_type_ids = unit_definition.combat_type_ids.duplicate()
        unit_state.base_attack = unit_definition.base_attack
        unit_state.base_defense = unit_definition.base_defense
        unit_state.base_sp_attack = unit_definition.base_sp_attack
        unit_state.base_sp_defense = unit_definition.base_sp_defense
        unit_state.base_speed = unit_definition.base_speed
        unit_state.last_effective_speed = unit_definition.base_speed
        side_state.public_labels[unit_state.unit_instance_id] = unit_state.public_id
        side_state.team_units.append(unit_state)
        if unit_index == side_setup.starting_index:
            side_state.set_active_unit(ContentSchemaScript.ACTIVE_SLOT_PRIMARY, unit_state.unit_instance_id)
        else:
            side_state.bench_order.append(unit_state.unit_instance_id)
    return side_state

func _resolve_regular_skill_loadout(side_setup, unit_index: int, unit_definition) -> PackedStringArray:
    if side_setup.regular_skill_loadout_overrides.has(unit_index):
        var override_loadout: PackedStringArray = side_setup.regular_skill_loadout_overrides[unit_index]
        assert(override_loadout.size() == 3, "Invalid regular skill loadout size for side %s slot %d" % [side_setup.side_id, unit_index])
        return override_loadout.duplicate()
    assert(unit_definition.skill_ids.size() == 3, "UnitDefinition.skill_ids must remain 3-slot default loadout for %s" % unit_definition.id)
    return unit_definition.skill_ids.duplicate()
