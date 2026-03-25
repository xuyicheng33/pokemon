extends RefCounted
class_name BattleCoreComposer

const BattleCoreContainerScript := preload("res://src/composition/battle_core_container.gd")
const IdFactoryScript := preload("res://src/shared/id_factory.gd")
const RngServiceScript := preload("res://src/shared/rng_service.gd")
const LegalActionServiceScript := preload("res://src/battle_core/commands/legal_action_service.gd")
const CommandBuilderScript := preload("res://src/battle_core/commands/command_builder.gd")
const CommandValidatorScript := preload("res://src/battle_core/commands/command_validator.gd")
const BattleInitializerScript := preload("res://src/battle_core/turn/battle_initializer.gd")
const ActionQueueBuilderScript := preload("res://src/battle_core/turn/action_queue_builder.gd")
const TurnLoopControllerScript := preload("res://src/battle_core/turn/turn_loop_controller.gd")
const ActionExecutorScript := preload("res://src/battle_core/actions/action_executor.gd")
const TargetResolverScript := preload("res://src/battle_core/actions/target_resolver.gd")
const StatCalculatorScript := preload("res://src/battle_core/math/stat_calculator.gd")
const MpServiceScript := preload("res://src/battle_core/math/mp_service.gd")
const HitServiceScript := preload("res://src/battle_core/math/hit_service.gd")
const DamageServiceScript := preload("res://src/battle_core/math/damage_service.gd")
const LeaveServiceScript := preload("res://src/battle_core/lifecycle/leave_service.gd")
const FaintResolverScript := preload("res://src/battle_core/lifecycle/faint_resolver.gd")
const DefaultReplacementSelectorScript := preload("res://src/battle_core/lifecycle/default_replacement_selector.gd")
const ReplacementServiceScript := preload("res://src/battle_core/lifecycle/replacement_service.gd")
const TriggerDispatcherScript := preload("res://src/battle_core/effects/trigger_dispatcher.gd")
const EffectQueueServiceScript := preload("res://src/battle_core/effects/effect_queue_service.gd")
const PayloadExecutorScript := preload("res://src/battle_core/effects/payload_executor.gd")
const EffectInstanceServiceScript := preload("res://src/battle_core/effects/effect_instance_service.gd")
const EffectInstanceDispatcherScript := preload("res://src/battle_core/effects/effect_instance_dispatcher.gd")
const RuleModServiceScript := preload("res://src/battle_core/effects/rule_mod_service.gd")
const PassiveSkillServiceScript := preload("res://src/battle_core/passives/passive_skill_service.gd")
const PassiveItemServiceScript := preload("res://src/battle_core/passives/passive_item_service.gd")
const FieldServiceScript := preload("res://src/battle_core/passives/field_service.gd")
const BattleLoggerScript := preload("res://src/battle_core/logging/battle_logger.gd")
const LogEventBuilderScript := preload("res://src/battle_core/logging/log_event_builder.gd")
const ReplayRunnerScript := preload("res://src/battle_core/logging/replay_runner.gd")

func compose():
    var container = BattleCoreContainerScript.new()
    container.id_factory = IdFactoryScript.new()
    container.rng_service = RngServiceScript.new()
    container.legal_action_service = LegalActionServiceScript.new()
    container.command_builder = CommandBuilderScript.new()
    container.command_validator = CommandValidatorScript.new()
    container.battle_initializer = BattleInitializerScript.new()
    container.action_queue_builder = ActionQueueBuilderScript.new()
    container.turn_loop_controller = TurnLoopControllerScript.new()
    container.action_executor = ActionExecutorScript.new()
    container.target_resolver = TargetResolverScript.new()
    container.stat_calculator = StatCalculatorScript.new()
    container.mp_service = MpServiceScript.new()
    container.hit_service = HitServiceScript.new()
    container.damage_service = DamageServiceScript.new()
    container.leave_service = LeaveServiceScript.new()
    container.faint_resolver = FaintResolverScript.new()
    container.replacement_selector = DefaultReplacementSelectorScript.new()
    container.replacement_service = ReplacementServiceScript.new()
    container.trigger_dispatcher = TriggerDispatcherScript.new()
    container.effect_queue_service = EffectQueueServiceScript.new()
    container.payload_executor = PayloadExecutorScript.new()
    container.effect_instance_service = EffectInstanceServiceScript.new()
    container.effect_instance_dispatcher = EffectInstanceDispatcherScript.new()
    container.rule_mod_service = RuleModServiceScript.new()
    container.passive_skill_service = PassiveSkillServiceScript.new()
    container.passive_item_service = PassiveItemServiceScript.new()
    container.field_service = FieldServiceScript.new()
    container.battle_logger = BattleLoggerScript.new()
    container.log_event_builder = LogEventBuilderScript.new()
    container.replay_runner = ReplayRunnerScript.new()
    container.command_builder.id_factory = container.id_factory
    container.legal_action_service.rule_mod_service = container.rule_mod_service
    container.battle_initializer.id_factory = container.id_factory
    container.battle_initializer.rng_service = container.rng_service
    container.battle_initializer.faint_resolver = container.faint_resolver
    container.battle_initializer.passive_skill_service = container.passive_skill_service
    container.battle_initializer.passive_item_service = container.passive_item_service
    container.battle_initializer.field_service = container.field_service
    container.battle_initializer.effect_instance_dispatcher = container.effect_instance_dispatcher
    container.battle_initializer.effect_queue_service = container.effect_queue_service
    container.battle_initializer.payload_executor = container.payload_executor
    container.battle_initializer.battle_logger = container.battle_logger
    container.battle_initializer.log_event_builder = container.log_event_builder
    container.action_queue_builder.id_factory = container.id_factory
    container.action_queue_builder.rng_service = container.rng_service
    container.action_queue_builder.stat_calculator = container.stat_calculator
    container.leave_service.battle_logger = container.battle_logger
    container.leave_service.log_event_builder = container.log_event_builder
    container.replacement_service.battle_logger = container.battle_logger
    container.replacement_service.log_event_builder = container.log_event_builder
    container.replacement_service.replacement_selector = container.replacement_selector
    container.replacement_service.leave_service = container.leave_service
    container.replacement_service.passive_skill_service = container.passive_skill_service
    container.replacement_service.passive_item_service = container.passive_item_service
    container.replacement_service.field_service = container.field_service
    container.replacement_service.effect_instance_dispatcher = container.effect_instance_dispatcher
    container.replacement_service.effect_queue_service = container.effect_queue_service
    container.replacement_service.payload_executor = container.payload_executor
    container.replacement_service.rng_service = container.rng_service
    container.faint_resolver.leave_service = container.leave_service
    container.faint_resolver.replacement_service = container.replacement_service
    container.faint_resolver.passive_skill_service = container.passive_skill_service
    container.faint_resolver.passive_item_service = container.passive_item_service
    container.faint_resolver.field_service = container.field_service
    container.faint_resolver.trigger_dispatcher = container.trigger_dispatcher
    container.faint_resolver.effect_instance_dispatcher = container.effect_instance_dispatcher
    container.faint_resolver.effect_queue_service = container.effect_queue_service
    container.faint_resolver.payload_executor = container.payload_executor
    container.faint_resolver.rng_service = container.rng_service
    container.faint_resolver.battle_logger = container.battle_logger
    container.faint_resolver.log_event_builder = container.log_event_builder
    container.trigger_dispatcher.id_factory = container.id_factory
    container.passive_skill_service.trigger_dispatcher = container.trigger_dispatcher
    container.passive_item_service.trigger_dispatcher = container.trigger_dispatcher
    container.field_service.trigger_dispatcher = container.trigger_dispatcher
    container.effect_instance_service.id_factory = container.id_factory
    container.effect_instance_dispatcher.id_factory = container.id_factory
    container.rule_mod_service.id_factory = container.id_factory
    container.payload_executor.battle_logger = container.battle_logger
    container.payload_executor.log_event_builder = container.log_event_builder
    container.payload_executor.id_factory = container.id_factory
    container.payload_executor.effect_instance_service = container.effect_instance_service
    container.payload_executor.rule_mod_service = container.rule_mod_service
    container.payload_executor.replacement_service = container.replacement_service
    container.payload_executor.damage_service = container.damage_service
    container.payload_executor.stat_calculator = container.stat_calculator
    container.payload_executor.faint_resolver = container.faint_resolver
    container.action_executor.mp_service = container.mp_service
    container.action_executor.hit_service = container.hit_service
    container.action_executor.damage_service = container.damage_service
    container.action_executor.stat_calculator = container.stat_calculator
    container.action_executor.rule_mod_service = container.rule_mod_service
    container.action_executor.leave_service = container.leave_service
    container.action_executor.passive_skill_service = container.passive_skill_service
    container.action_executor.passive_item_service = container.passive_item_service
    container.action_executor.field_service = container.field_service
    container.action_executor.target_resolver = container.target_resolver
    container.action_executor.trigger_dispatcher = container.trigger_dispatcher
    container.action_executor.effect_instance_dispatcher = container.effect_instance_dispatcher
    container.action_executor.effect_queue_service = container.effect_queue_service
    container.action_executor.payload_executor = container.payload_executor
    container.action_executor.faint_resolver = container.faint_resolver
    container.action_executor.battle_logger = container.battle_logger
    container.action_executor.log_event_builder = container.log_event_builder
    container.action_executor.rng_service = container.rng_service
    container.turn_loop_controller.id_factory = container.id_factory
    container.turn_loop_controller.legal_action_service = container.legal_action_service
    container.turn_loop_controller.command_builder = container.command_builder
    container.turn_loop_controller.command_validator = container.command_validator
    container.turn_loop_controller.action_queue_builder = container.action_queue_builder
    container.turn_loop_controller.action_executor = container.action_executor
    container.turn_loop_controller.faint_resolver = container.faint_resolver
    container.turn_loop_controller.mp_service = container.mp_service
    container.turn_loop_controller.field_service = container.field_service
    container.turn_loop_controller.passive_skill_service = container.passive_skill_service
    container.turn_loop_controller.passive_item_service = container.passive_item_service
    container.turn_loop_controller.effect_instance_dispatcher = container.effect_instance_dispatcher
    container.turn_loop_controller.effect_queue_service = container.effect_queue_service
    container.turn_loop_controller.payload_executor = container.payload_executor
    container.turn_loop_controller.rule_mod_service = container.rule_mod_service
    container.turn_loop_controller.rng_service = container.rng_service
    container.turn_loop_controller.battle_logger = container.battle_logger
    container.turn_loop_controller.log_event_builder = container.log_event_builder
    container.replay_runner.battle_initializer = container.battle_initializer
    container.replay_runner.turn_loop_controller = container.turn_loop_controller
    container.replay_runner.battle_logger = container.battle_logger
    container.replay_runner.id_factory = container.id_factory
    container.replay_runner.rng_service = container.rng_service
    _assert_container_dependencies(container)
    return container

func _assert_container_dependencies(container) -> void:
    _assert_dependency(container.legal_action_service, "legal_action_service", "rule_mod_service")
    _assert_dependency(container.battle_initializer, "battle_initializer", "effect_instance_dispatcher")
    _assert_dependency(container.turn_loop_controller, "turn_loop_controller", "effect_instance_dispatcher")
    _assert_dependency(container.turn_loop_controller, "turn_loop_controller", "rule_mod_service")
    _assert_dependency(container.action_executor, "action_executor", "effect_instance_dispatcher")
    _assert_dependency(container.faint_resolver, "faint_resolver", "effect_instance_dispatcher")
    _assert_dependency(container.payload_executor, "payload_executor", "replacement_service")
    _assert_dependency(container.replacement_service, "replacement_service", "payload_executor")

func _assert_dependency(owner, owner_name: String, dependency_name: String) -> void:
    assert(owner != null, "Composer missing owner: %s" % owner_name)
    assert(owner.get(dependency_name) != null, "%s missing dependency: %s" % [owner_name, dependency_name])
