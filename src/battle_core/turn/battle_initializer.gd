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
var faint_resolver
var passive_skill_service
var passive_item_service
var field_service
var effect_instance_dispatcher
var effect_queue_service
var payload_executor
var battle_logger
var log_event_builder

func initialize_battle(battle_state, content_index, battle_setup) -> void:
    assert(battle_setup != null, "Battle setup is required")
    var format_config = content_index.battle_formats.get(battle_setup.format_id)
    assert(format_config != null, "Missing battle format: %s" % battle_setup.format_id)
    assert(battle_setup.sides.size() == 2, "Current baseline requires exactly 2 sides")
    for side_setup in battle_setup.sides:
        _validate_side_setup_constraints(side_setup, format_config, content_index)
    battle_logger.reset()
    battle_state.format_id = battle_setup.format_id
    battle_state.max_turn = format_config.max_turn
    battle_state.max_chain_depth = max(1, int(format_config.max_chain_depth))
    battle_state.battle_level = format_config.level
    battle_state.selection_deadline_ms = format_config.selection_deadline_ms
    battle_state.rng_profile = rng_service.get_profile()
    battle_state.phase = BattlePhasesScript.BATTLE_INIT
    battle_state.turn_index = 1
    battle_state.battle_result = BattleResultScript.new()
    battle_state.sides.clear()
    battle_state.fatal_damage_records_by_target.clear()
    battle_state.field_rule_mod_instances.clear()
    for side_setup in battle_setup.sides:
        var side_state = _build_side_state(side_setup, format_config, content_index)
        battle_state.sides.append(side_state)

    var initial_active_ids: Array = _collect_active_unit_ids(battle_state)
    battle_state.chain_context = _build_system_chain("system:replace", "system_replace")
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        battle_logger.append_event(log_event_builder.build_event(
            EventTypesScript.STATE_ENTER,
            battle_state,
            {
                "source_instance_id": active_unit.unit_instance_id,
                "target_instance_id": active_unit.unit_instance_id,
                "target_slot": ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
                "trigger_name": "on_enter",
                "payload_summary": "%s entered battle" % active_unit.public_id,
            }
        ))
    var on_enter_invalid_code = _execute_trigger_batch("on_enter", battle_state, content_index, initial_active_ids)
    if on_enter_invalid_code != null:
        _terminate_invalid_battle(battle_state, str(on_enter_invalid_code))
        return
    var on_enter_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if on_enter_faint_invalid_code != null:
        _terminate_invalid_battle(battle_state, str(on_enter_faint_invalid_code))
        return
    if _resolve_startup_victory(battle_state):
        return

    battle_state.chain_context = _build_battle_init_chain()
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_BATTLE_INIT,
        battle_state,
        {
            "source_instance_id": "system:battle_init",
            "trigger_name": "battle_init",
            "payload_summary": "battle initialized",
        }
    ))
    var battle_init_owner_ids: Array = _collect_active_unit_ids(battle_state)
    var battle_init_invalid_code = _execute_trigger_batch("battle_init", battle_state, content_index, battle_init_owner_ids)
    if battle_init_invalid_code != null:
        _terminate_invalid_battle(battle_state, str(battle_init_invalid_code))
        return
    var battle_init_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if battle_init_faint_invalid_code != null:
        _terminate_invalid_battle(battle_state, str(battle_init_faint_invalid_code))
        return
    if _resolve_startup_victory(battle_state):
        return

    battle_state.phase = BattlePhasesScript.SELECTION

func _build_side_state(side_setup, format_config, content_index):
    assert(side_setup.unit_definition_ids.size() == format_config.team_size, "Side %s must provide exactly %d units" % [side_setup.side_id, format_config.team_size])
    assert(side_setup.starting_index >= 0 and side_setup.starting_index < side_setup.unit_definition_ids.size(), "Invalid starting index for %s" % side_setup.side_id)
    var side_state = SideStateScript.new()
    side_state.side_id = side_setup.side_id
    side_state.selection_state = SelectionStateScript.new()
    var label_suffixes = ["A", "B", "C", "D"]
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

func _validate_side_setup_constraints(side_setup, format_config, content_index) -> void:
    assert(side_setup.unit_definition_ids.size() == format_config.team_size, "Side %s must provide exactly %d units" % [side_setup.side_id, format_config.team_size])
    assert(side_setup.starting_index >= 0 and side_setup.starting_index < side_setup.unit_definition_ids.size(), "Invalid starting index for %s" % side_setup.side_id)
    var seen_passive_items: Dictionary = {}
    for unit_definition_id in side_setup.unit_definition_ids:
        var unit_definition = content_index.units.get(unit_definition_id)
        assert(unit_definition != null, "Missing unit definition: %s" % unit_definition_id)
        var passive_item_id := str(unit_definition.passive_item_id)
        if passive_item_id.is_empty():
            continue
        assert(not seen_passive_items.has(passive_item_id), "Side %s duplicated passive_item_id: %s" % [side_setup.side_id, passive_item_id])
        seen_passive_items[passive_item_id] = true

func _execute_trigger_batch(trigger_name: String, battle_state, content_index, owner_unit_ids: Array):
    var effect_events: Array = []
    effect_events.append_array(passive_skill_service.collect_trigger_events(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context))
    effect_events.append_array(passive_item_service.collect_trigger_events(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context))
    if effect_instance_dispatcher != null:
        effect_events.append_array(effect_instance_dispatcher.collect_trigger_events(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context))
    effect_events.append_array(field_service.collect_trigger_events(trigger_name, battle_state, content_index, battle_state.chain_context))
    if effect_events.is_empty():
        return null
    battle_state.pending_effect_queue = effect_events
    var sorted_events = effect_queue_service.sort_events(effect_events, rng_service)
    battle_state.rng_stream_index = rng_service.get_stream_index()
    for effect_event in sorted_events:
        payload_executor.execute_effect_event(effect_event, battle_state, content_index)
        if payload_executor.last_invalid_battle_code != null:
            battle_state.pending_effect_queue.clear()
            return payload_executor.last_invalid_battle_code
    battle_state.pending_effect_queue.clear()
    return null

func _collect_active_unit_ids(battle_state) -> Array:
    var active_ids: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit != null and active_unit.current_hp > 0:
            active_ids.append(active_unit.unit_instance_id)
    return active_ids

func _resolve_startup_victory(battle_state) -> bool:
    var alive_side_ids: Array = []
    for side_state in battle_state.sides:
        if _side_has_available_unit(side_state):
            alive_side_ids.append(side_state.side_id)
    if alive_side_ids.size() == battle_state.sides.size():
        return false
    battle_state.battle_result.finished = true
    battle_state.phase = BattlePhasesScript.FINISHED
    if alive_side_ids.is_empty():
        battle_state.battle_result.winner_side_id = null
        battle_state.battle_result.result_type = "draw"
        battle_state.battle_result.reason = "double_faint"
    else:
        battle_state.battle_result.winner_side_id = alive_side_ids[0]
        battle_state.battle_result.result_type = "win"
        battle_state.battle_result.reason = "elimination"
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.RESULT_BATTLE_END,
        battle_state,
        {
            "source_instance_id": "system:battle_end",
            "payload_summary": "battle finished during initialization",
        }
    ))
    return true

func _side_has_available_unit(side_state) -> bool:
    for unit_state in side_state.team_units:
        if unit_state.current_hp > 0:
            return true
    return false

func _terminate_invalid_battle(battle_state, invalid_code: String) -> void:
    battle_state.battle_result.finished = true
    battle_state.battle_result.winner_side_id = null
    battle_state.battle_result.result_type = "no_winner"
    battle_state.battle_result.reason = invalid_code
    battle_state.phase = BattlePhasesScript.FINISHED
    battle_state.chain_context = _build_system_chain(EventTypesScript.SYSTEM_INVALID_BATTLE, "system_replace")
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_INVALID_BATTLE,
        battle_state,
        {
            "source_instance_id": "system:invalid_battle",
            "invalid_battle_code": invalid_code,
            "payload_summary": "invalid battle: %s" % invalid_code,
        }
    ))

func _build_battle_init_chain():
    return _build_system_chain(EventTypesScript.SYSTEM_BATTLE_INIT, "battle_init")

func _build_system_chain(command_type: String, chain_origin: String):
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = id_factory.next_id("chain")
    chain_context.chain_origin = chain_origin
    chain_context.command_type = command_type
    chain_context.command_source = "system"
    chain_context.select_deadline_ms = null
    chain_context.select_timeout = null
    return chain_context
