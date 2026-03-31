extends RefCounted
class_name BattleInitializer

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const BattleResultScript := preload("res://src/battle_core/contracts/battle_result.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const PublicIdAllocatorScript := preload("res://src/battle_core/turn/public_id_allocator.gd")
const BattleInitializerStateBuilderScript := preload("res://src/battle_core/turn/battle_initializer_state_builder.gd")

var id_factory
var rng_service
var faint_resolver
var field_service
var trigger_batch_runner
var battle_logger
var log_event_builder
var public_snapshot_builder
var combat_type_service
var mp_service
var rule_mod_service
var battle_result_service
var field_lifecycle_service
var public_id_allocator = PublicIdAllocatorScript.new()
var _state_builder = BattleInitializerStateBuilderScript.new()

func initialize_battle(battle_state, content_index, battle_setup) -> void:
    assert(battle_setup != null, "Battle setup is required")
    assert(public_snapshot_builder != null, "BattleInitializer requires public_snapshot_builder")
    assert(combat_type_service != null, "BattleInitializer requires combat_type_service")
    assert(public_id_allocator != null, "BattleInitializer requires public_id_allocator")
    assert(battle_result_service != null, "BattleInitializer requires battle_result_service")
    var format_config = content_index.battle_formats.get(battle_setup.format_id)
    assert(format_config != null, "Missing battle format: %s" % battle_setup.format_id)
    combat_type_service.build_chart(format_config.combat_type_chart)
    assert(battle_setup.sides.size() == 2, "Current baseline requires exactly 2 sides")
    var setup_errors: Array = content_index.validate_setup(battle_setup)
    assert(setup_errors.is_empty(), "Battle setup validation failed:\n%s" % "\n".join(setup_errors))
    battle_logger.reset()
    battle_state.format_id = battle_setup.format_id
    battle_state.visibility_mode = String(format_config.visibility_mode).strip_edges()
    assert(not battle_state.visibility_mode.is_empty(), "Battle format visibility_mode must not be empty: %s" % battle_setup.format_id)
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
    battle_state.last_matchup_signature = ""
    battle_state.pre_applied_turn_start_regen_turn_index = 0
    for side_setup in battle_setup.sides:
        var side_state = _state_builder.build_side_state(side_setup, format_config, content_index, id_factory, public_id_allocator)
        battle_state.sides.append(side_state)
    battle_state.chain_context = _build_system_chain(EventTypesScript.SYSTEM_BATTLE_HEADER, "battle_init")
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.SYSTEM_BATTLE_HEADER,
        battle_state,
        {
            "source_instance_id": EventTypesScript.SYSTEM_BATTLE_HEADER,
            "header_snapshot": public_snapshot_builder.build_header_snapshot(battle_state, content_index),
            "payload_summary": "battle header",
        }
    ))
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
        battle_result_service.terminate_invalid_battle(battle_state, str(on_enter_invalid_code))
        return
    var on_enter_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if on_enter_faint_invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(on_enter_faint_invalid_code))
        return
    if field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index):
        return
    if battle_result_service.resolve_initialization_victory(battle_state):
        return
    battle_state.chain_context = _build_system_chain(EventTypesScript.SYSTEM_BATTLE_INIT, "battle_init")
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
        battle_result_service.terminate_invalid_battle(battle_state, str(battle_init_invalid_code))
        return
    var battle_init_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if battle_init_faint_invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(battle_init_faint_invalid_code))
        return
    if battle_result_service.resolve_initialization_victory(battle_state):
        return
    if field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index):
        return
    _apply_initial_turn_start_regen(battle_state)
    battle_state.phase = BattlePhasesScript.SELECTION

func _execute_trigger_batch(trigger_name: String, battle_state, content_index, owner_unit_ids: Array):
    return trigger_batch_runner.execute_trigger_batch(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context)

func _collect_active_unit_ids(battle_state) -> Array:
    var active_ids: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit != null and active_unit.current_hp > 0:
            active_ids.append(active_unit.unit_instance_id)
    return active_ids

func _apply_initial_turn_start_regen(battle_state) -> void:
    assert(mp_service != null, "BattleInitializer requires mp_service for initial turn_start regen")
    assert(rule_mod_service != null, "BattleInitializer requires rule_mod_service for initial turn_start regen")
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null or active_unit.current_hp <= 0:
            continue
        var regen_value: int = rule_mod_service.resolve_mp_regen_value(
            battle_state,
            active_unit.unit_instance_id,
            active_unit.regen_per_turn
        )
        active_unit.current_mp = mp_service.apply_turn_start_regen(
            active_unit.current_mp,
            regen_value,
            active_unit.max_mp
        )
    battle_state.pre_applied_turn_start_regen_turn_index = battle_state.turn_index

func _build_system_chain(command_type: String, chain_origin: String):
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = id_factory.next_id("chain")
    chain_context.chain_origin = chain_origin
    chain_context.command_type = command_type
    chain_context.command_source = "system"
    chain_context.select_deadline_ms = null
    chain_context.select_timeout = null
    return chain_context
