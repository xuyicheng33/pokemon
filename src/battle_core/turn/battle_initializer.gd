extends RefCounted
class_name BattleInitializer

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const BattleResultScript := preload("res://src/battle_core/contracts/battle_result.gd")
const SideStateScript := preload("res://src/battle_core/runtime/side_state.gd")
const SelectionStateScript := preload("res://src/battle_core/contracts/selection_state.gd")
const UnitStateScript := preload("res://src/battle_core/runtime/unit_state.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")

var id_factory
var rng_service
var battle_logger
var log_event_builder

func initialize_battle(battle_state, content_index, battle_setup) -> void:
    assert(battle_setup != null, "Battle setup is required")
    var format_config = content_index.battle_formats.get(battle_setup.format_id)
    assert(format_config != null, "Missing battle format: %s" % battle_setup.format_id)
    assert(battle_setup.sides.size() == 2, "Current baseline requires exactly 2 sides")
    battle_logger.reset()
    battle_state.format_id = battle_setup.format_id
    battle_state.max_turn = format_config.max_turn
    battle_state.battle_level = format_config.level
    battle_state.selection_deadline_ms = format_config.selection_deadline_ms
    battle_state.rng_profile = rng_service.get_profile()
    battle_state.phase = BattlePhasesScript.BATTLE_INIT
    battle_state.turn_index = 1
    battle_state.battle_result = BattleResultScript.new()
    battle_state.sides.clear()
    for side_setup in battle_setup.sides:
        var side_state = _build_side_state(side_setup, format_config, content_index)
        battle_state.sides.append(side_state)
    battle_state.chain_context = _build_battle_init_chain()
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        battle_logger.append_event(log_event_builder.build_event(
            EventTypesScript.STATE_ENTER,
            battle_state,
            {
                "source_instance_id": active_unit.unit_instance_id,
                "target_instance_id": active_unit.unit_instance_id,
                "target_slot": ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
                "payload_summary": "%s entered battle" % active_unit.public_id,
            }
        ))
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_BATTLE_INIT,
        battle_state,
        {
            "source_instance_id": "system:battle_init",
            "payload_summary": "battle initialized",
        }
    ))
    battle_state.phase = BattlePhasesScript.SELECTION

func _build_side_state(side_setup, format_config, content_index):
    assert(side_setup.unit_definition_ids.size() == format_config.team_size, "Side %s must provide exactly %d units" % [side_setup.side_id, format_config.team_size])
    assert(side_setup.starting_index >= 0 and side_setup.starting_index < side_setup.unit_definition_ids.size(), "Invalid starting index for %s" % side_setup.side_id)
    var side_state = SideStateScript.new()
    side_state.side_id = side_setup.side_id
    side_state.selection_state = SelectionStateScript.new()
    var label_suffixes := ["A", "B", "C", "D"]
    for unit_index in range(side_setup.unit_definition_ids.size()):
        var unit_definition_id = side_setup.unit_definition_ids[unit_index]
        var unit_definition = content_index.units.get(unit_definition_id)
        assert(unit_definition != null, "Missing unit definition: %s" % unit_definition_id)
        var unit_state = UnitStateScript.new()
        unit_state.unit_instance_id = id_factory.next_id("unit")
        unit_state.public_id = "%s-%s" % [side_setup.side_id, label_suffixes[unit_index]]
        unit_state.definition_id = unit_definition.id
        unit_state.display_name = unit_definition.display_name
        unit_state.max_hp = unit_definition.base_hp
        unit_state.current_hp = unit_definition.base_hp
        unit_state.max_mp = unit_definition.max_mp
        unit_state.current_mp = unit_definition.init_mp
        unit_state.regen_per_turn = unit_definition.regen_per_turn
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

func _build_battle_init_chain():
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = id_factory.next_id("chain")
    chain_context.chain_origin = "battle_init"
    chain_context.command_type = EventTypesScript.SYSTEM_BATTLE_INIT
    chain_context.command_source = "system"
    return chain_context
