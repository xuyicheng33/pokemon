extends RefCounted
class_name BattleCoreContainer

var id_factory
var rng_service
var legal_action_service
var command_builder
var command_validator
var battle_initializer
var action_queue_builder
var turn_loop_controller
var turn_resolution_service
var turn_selection_resolver
var turn_field_lifecycle_service
var battle_result_service
var runtime_guard_service
var action_executor
var action_cast_service
var switch_action_service
var action_log_service
var target_resolver
var stat_calculator
var mp_service
var hit_service
var damage_service
var combat_type_service
var leave_service
var faint_resolver
var replacement_selector
var replacement_service
var trigger_dispatcher
var trigger_batch_runner
var effect_queue_service
var payload_executor
var payload_numeric_handler
var payload_state_handler
var payload_forced_replace_handler
var effect_instance_service
var effect_instance_dispatcher
var rule_mod_service
var rule_mod_value_resolver
var passive_skill_service
var passive_item_service
var field_service
var battle_logger
var log_event_builder
var public_snapshot_builder
var replay_runner

func dispose() -> void:
    if action_executor != null:
        action_executor.action_cast_service = null
        action_executor.switch_action_service = null
        action_executor.action_log_service = null
    if action_cast_service != null:
        action_cast_service.mp_service = null
        action_cast_service.hit_service = null
        action_cast_service.damage_service = null
        action_cast_service.combat_type_service = null
        action_cast_service.stat_calculator = null
        action_cast_service.rule_mod_service = null
        action_cast_service.target_resolver = null
        action_cast_service.trigger_dispatcher = null
        action_cast_service.effect_queue_service = null
        action_cast_service.payload_executor = null
        action_cast_service.faint_resolver = null
        action_cast_service.trigger_batch_runner = null
        action_cast_service.rng_service = null
        action_cast_service.action_log_service = null
    if switch_action_service != null:
        switch_action_service.leave_service = null
        switch_action_service.action_cast_service = null
        switch_action_service.action_log_service = null
    if action_log_service != null:
        action_log_service.battle_logger = null
        action_log_service.log_event_builder = null
    if payload_executor != null:
        payload_executor.numeric_payload_handler = null
        payload_executor.state_payload_handler = null
        payload_executor.forced_replace_payload_handler = null
    if payload_numeric_handler != null:
        payload_numeric_handler.battle_logger = null
        payload_numeric_handler.log_event_builder = null
        payload_numeric_handler.damage_service = null
        payload_numeric_handler.combat_type_service = null
        payload_numeric_handler.stat_calculator = null
        payload_numeric_handler.rule_mod_service = null
        payload_numeric_handler.faint_resolver = null
    if payload_state_handler != null:
        payload_state_handler.battle_logger = null
        payload_state_handler.log_event_builder = null
        payload_state_handler.id_factory = null
        payload_state_handler.effect_instance_service = null
        payload_state_handler.rule_mod_service = null
        payload_state_handler.rule_mod_value_resolver = null
    if payload_forced_replace_handler != null:
        payload_forced_replace_handler.replacement_service = null
    if faint_resolver != null:
        faint_resolver.leave_service = null
        faint_resolver.replacement_service = null
        faint_resolver.passive_skill_service = null
        faint_resolver.passive_item_service = null
        faint_resolver.field_service = null
        faint_resolver.trigger_dispatcher = null
        faint_resolver.effect_instance_dispatcher = null
        faint_resolver.effect_queue_service = null
        faint_resolver.payload_executor = null
        faint_resolver.trigger_batch_runner = null
        faint_resolver.rng_service = null
        faint_resolver.battle_logger = null
        faint_resolver.log_event_builder = null
    if battle_initializer != null:
        battle_initializer.id_factory = null
        battle_initializer.rng_service = null
        battle_initializer.faint_resolver = null
        battle_initializer.field_service = null
        battle_initializer.trigger_batch_runner = null
        battle_initializer.battle_logger = null
        battle_initializer.log_event_builder = null
        battle_initializer.public_snapshot_builder = null
        battle_initializer.combat_type_service = null
    if turn_loop_controller != null:
        turn_loop_controller.action_queue_builder = null
        turn_loop_controller.action_executor = null
        turn_loop_controller.faint_resolver = null
        turn_loop_controller.turn_resolution_service = null
        turn_loop_controller.battle_result_service = null
        turn_loop_controller.runtime_guard_service = null
        turn_loop_controller.battle_logger = null
        turn_loop_controller.log_event_builder = null
    if turn_resolution_service != null:
        turn_resolution_service.selection_resolver = null
        turn_resolution_service.field_lifecycle_service = null
        turn_resolution_service.mp_service = null
        turn_resolution_service.trigger_batch_runner = null
        turn_resolution_service.effect_instance_dispatcher = null
        turn_resolution_service.rule_mod_service = null
        turn_resolution_service.faint_resolver = null
        turn_resolution_service.battle_logger = null
        turn_resolution_service.log_event_builder = null
        turn_resolution_service.battle_result_service = null
    if turn_selection_resolver != null:
        turn_selection_resolver.legal_action_service = null
        turn_selection_resolver.command_builder = null
        turn_selection_resolver.command_validator = null
    if turn_field_lifecycle_service != null:
        turn_field_lifecycle_service.field_service = null
        turn_field_lifecycle_service.trigger_batch_runner = null
        turn_field_lifecycle_service.battle_logger = null
        turn_field_lifecycle_service.log_event_builder = null
        turn_field_lifecycle_service.battle_result_service = null
    if battle_result_service != null:
        battle_result_service.id_factory = null
        battle_result_service.battle_logger = null
        battle_result_service.log_event_builder = null
    if replay_runner != null:
        replay_runner.battle_initializer = null
        replay_runner.turn_loop_controller = null
        replay_runner.battle_logger = null
        replay_runner.id_factory = null
        replay_runner.rng_service = null
    if legal_action_service != null:
        legal_action_service.rule_mod_service = null
    if command_builder != null:
        command_builder.id_factory = null
    if action_queue_builder != null:
        action_queue_builder.id_factory = null
        action_queue_builder.rng_service = null
        action_queue_builder.stat_calculator = null
    if trigger_dispatcher != null:
        trigger_dispatcher.id_factory = null
    if trigger_batch_runner != null:
        trigger_batch_runner.passive_skill_service = null
        trigger_batch_runner.passive_item_service = null
        trigger_batch_runner.field_service = null
        trigger_batch_runner.effect_instance_dispatcher = null
        trigger_batch_runner.effect_queue_service = null
        trigger_batch_runner.payload_executor = null
        trigger_batch_runner.rng_service = null
    if passive_skill_service != null:
        passive_skill_service.trigger_dispatcher = null
    if passive_item_service != null:
        passive_item_service.trigger_dispatcher = null
    if field_service != null:
        field_service.trigger_dispatcher = null
    if effect_instance_service != null:
        effect_instance_service.id_factory = null
    if effect_instance_dispatcher != null:
        effect_instance_dispatcher.id_factory = null
    if rule_mod_service != null:
        rule_mod_service.id_factory = null
    if rule_mod_value_resolver != null:
        rule_mod_value_resolver.last_error_code = null
    if leave_service != null:
        leave_service.battle_logger = null
        leave_service.log_event_builder = null
    if replacement_service != null:
        replacement_service.battle_logger = null
        replacement_service.log_event_builder = null
        replacement_service.replacement_selector = null
        replacement_service.leave_service = null
        replacement_service.trigger_batch_runner = null

    id_factory = null
    rng_service = null
    legal_action_service = null
    command_builder = null
    command_validator = null
    battle_initializer = null
    action_queue_builder = null
    turn_loop_controller = null
    turn_resolution_service = null
    turn_selection_resolver = null
    turn_field_lifecycle_service = null
    battle_result_service = null
    runtime_guard_service = null
    action_executor = null
    action_cast_service = null
    switch_action_service = null
    action_log_service = null
    target_resolver = null
    stat_calculator = null
    mp_service = null
    hit_service = null
    damage_service = null
    combat_type_service = null
    leave_service = null
    faint_resolver = null
    replacement_selector = null
    replacement_service = null
    trigger_dispatcher = null
    trigger_batch_runner = null
    effect_queue_service = null
    payload_executor = null
    payload_numeric_handler = null
    payload_state_handler = null
    payload_forced_replace_handler = null
    effect_instance_service = null
    effect_instance_dispatcher = null
    rule_mod_service = null
    rule_mod_value_resolver = null
    passive_skill_service = null
    passive_item_service = null
    field_service = null
    battle_logger = null
    log_event_builder = null
    public_snapshot_builder = null
    replay_runner = null
