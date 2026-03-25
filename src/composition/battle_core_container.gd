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
var action_executor
var target_resolver
var stat_calculator
var mp_service
var hit_service
var damage_service
var leave_service
var faint_resolver
var replacement_selector
var replacement_service
var trigger_dispatcher
var effect_queue_service
var payload_executor
var effect_instance_service
var effect_instance_dispatcher
var rule_mod_service
var passive_skill_service
var passive_item_service
var field_service
var battle_logger
var log_event_builder
var replay_runner

func dispose() -> void:
    if action_executor != null:
        action_executor.mp_service = null
        action_executor.hit_service = null
        action_executor.damage_service = null
        action_executor.stat_calculator = null
        action_executor.rule_mod_service = null
        action_executor.leave_service = null
        action_executor.passive_skill_service = null
        action_executor.passive_item_service = null
        action_executor.field_service = null
        action_executor.target_resolver = null
        action_executor.trigger_dispatcher = null
        action_executor.effect_instance_dispatcher = null
        action_executor.effect_queue_service = null
        action_executor.payload_executor = null
        action_executor.faint_resolver = null
        action_executor.battle_logger = null
        action_executor.log_event_builder = null
        action_executor.rng_service = null
    if payload_executor != null:
        payload_executor.battle_logger = null
        payload_executor.log_event_builder = null
        payload_executor.id_factory = null
        payload_executor.effect_instance_service = null
        payload_executor.rule_mod_service = null
        payload_executor.replacement_service = null
        payload_executor.damage_service = null
        payload_executor.stat_calculator = null
        payload_executor.faint_resolver = null
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
        faint_resolver.rng_service = null
        faint_resolver.battle_logger = null
        faint_resolver.log_event_builder = null
    if battle_initializer != null:
        battle_initializer.id_factory = null
        battle_initializer.rng_service = null
        battle_initializer.faint_resolver = null
        battle_initializer.passive_skill_service = null
        battle_initializer.passive_item_service = null
        battle_initializer.field_service = null
        battle_initializer.effect_instance_dispatcher = null
        battle_initializer.effect_queue_service = null
        battle_initializer.payload_executor = null
        battle_initializer.battle_logger = null
        battle_initializer.log_event_builder = null
    if turn_loop_controller != null:
        turn_loop_controller.id_factory = null
        turn_loop_controller.legal_action_service = null
        turn_loop_controller.command_builder = null
        turn_loop_controller.command_validator = null
        turn_loop_controller.action_queue_builder = null
        turn_loop_controller.action_executor = null
        turn_loop_controller.faint_resolver = null
        turn_loop_controller.mp_service = null
        turn_loop_controller.field_service = null
        turn_loop_controller.passive_skill_service = null
        turn_loop_controller.passive_item_service = null
        turn_loop_controller.effect_instance_dispatcher = null
        turn_loop_controller.effect_queue_service = null
        turn_loop_controller.payload_executor = null
        turn_loop_controller.rule_mod_service = null
        turn_loop_controller.rng_service = null
        turn_loop_controller.battle_logger = null
        turn_loop_controller.log_event_builder = null
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
    if leave_service != null:
        leave_service.battle_logger = null
        leave_service.log_event_builder = null
    if replacement_service != null:
        replacement_service.battle_logger = null
        replacement_service.log_event_builder = null
        replacement_service.replacement_selector = null
        replacement_service.leave_service = null
        replacement_service.passive_skill_service = null
        replacement_service.passive_item_service = null
        replacement_service.field_service = null
        replacement_service.effect_instance_dispatcher = null
        replacement_service.effect_queue_service = null
        replacement_service.payload_executor = null
        replacement_service.rng_service = null

    id_factory = null
    rng_service = null
    legal_action_service = null
    command_builder = null
    command_validator = null
    battle_initializer = null
    action_queue_builder = null
    turn_loop_controller = null
    action_executor = null
    target_resolver = null
    stat_calculator = null
    mp_service = null
    hit_service = null
    damage_service = null
    leave_service = null
    faint_resolver = null
    replacement_selector = null
    replacement_service = null
    trigger_dispatcher = null
    effect_queue_service = null
    payload_executor = null
    effect_instance_service = null
    effect_instance_dispatcher = null
    rule_mod_service = null
    passive_skill_service = null
    passive_item_service = null
    field_service = null
    battle_logger = null
    log_event_builder = null
    replay_runner = null
