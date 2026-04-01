extends RefCounted
class_name BattleInitializerPhaseService

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")

const INIT_PHASE_CONTINUE := 0
const INIT_PHASE_STOP := 1
const INIT_PHASE_FAIL := 2

var id_factory
var faint_resolver
var trigger_batch_runner
var battle_logger
var log_event_builder
var public_snapshot_builder
var mp_service
var rule_mod_service
var battle_result_service
var field_lifecycle_service

func resolve_missing_dependency() -> String:
    if id_factory == null:
        return "id_factory"
    if faint_resolver == null:
        return "faint_resolver"
    var faint_missing := _resolve_nested_missing_dependency(faint_resolver)
    if not faint_missing.is_empty():
        return "faint_resolver.%s" % faint_missing
    if trigger_batch_runner == null:
        return "trigger_batch_runner"
    var trigger_batch_missing := _resolve_nested_missing_dependency(trigger_batch_runner)
    if not trigger_batch_missing.is_empty():
        return "trigger_batch_runner.%s" % trigger_batch_missing
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if public_snapshot_builder == null:
        return "public_snapshot_builder"
    if mp_service == null:
        return "mp_service"
    if rule_mod_service == null:
        return "rule_mod_service"
    if battle_result_service == null:
        return "battle_result_service"
    var battle_result_missing := _resolve_nested_missing_dependency(battle_result_service)
    if not battle_result_missing.is_empty():
        return "battle_result_service.%s" % battle_result_missing
    if field_lifecycle_service == null:
        return "field_lifecycle_service"
    var field_lifecycle_missing := _resolve_nested_missing_dependency(field_lifecycle_service)
    if not field_lifecycle_missing.is_empty():
        return "field_lifecycle_service.%s" % field_lifecycle_missing
    return ""

func append_battle_header_event(battle_state, content_index) -> void:
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

func run_on_enter_phase(battle_state, content_index) -> int:
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
    var on_enter_invalid_code = _execute_trigger_batch("on_enter", battle_state, content_index, _collect_active_unit_ids(battle_state))
    if on_enter_invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(on_enter_invalid_code))
        return INIT_PHASE_FAIL
    var on_enter_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if on_enter_faint_invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(on_enter_faint_invalid_code))
        return INIT_PHASE_FAIL
    return INIT_PHASE_STOP if field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index) else INIT_PHASE_CONTINUE

func run_battle_init_phase(battle_state, content_index) -> int:
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
    var battle_init_invalid_code = _execute_trigger_batch("battle_init", battle_state, content_index, _collect_active_unit_ids(battle_state))
    if battle_init_invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(battle_init_invalid_code))
        return INIT_PHASE_FAIL
    var battle_init_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
    if battle_init_faint_invalid_code != null:
        battle_result_service.terminate_invalid_battle(battle_state, str(battle_init_faint_invalid_code))
        return INIT_PHASE_FAIL
    return INIT_PHASE_STOP if field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index) else INIT_PHASE_CONTINUE

func apply_initial_turn_start_regen(battle_state) -> void:
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

func _execute_trigger_batch(trigger_name: String, battle_state, content_index, owner_unit_ids: Array):
    return trigger_batch_runner.execute_trigger_batch(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context)

func _collect_active_unit_ids(battle_state) -> Array:
    var active_ids: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit != null and active_unit.current_hp > 0:
            active_ids.append(active_unit.unit_instance_id)
    return active_ids

func _build_system_chain(command_type: String, chain_origin: String):
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = id_factory.next_id("chain")
    chain_context.chain_origin = chain_origin
    chain_context.command_type = command_type
    chain_context.command_source = "system"
    chain_context.select_deadline_ms = null
    chain_context.select_timeout = null
    return chain_context

func _resolve_nested_missing_dependency(service) -> String:
    if service == null or not service.has_method("resolve_missing_dependency"):
        return ""
    return str(service.resolve_missing_dependency())
