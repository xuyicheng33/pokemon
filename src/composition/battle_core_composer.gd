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
const TurnResolutionServiceScript := preload("res://src/battle_core/turn/turn_resolution_service.gd")
const TurnSelectionResolverScript := preload("res://src/battle_core/turn/turn_selection_resolver.gd")
const TurnFieldLifecycleServiceScript := preload("res://src/battle_core/turn/turn_field_lifecycle_service.gd")
const BattleResultServiceScript := preload("res://src/battle_core/turn/battle_result_service.gd")
const RuntimeGuardServiceScript := preload("res://src/battle_core/turn/runtime_guard_service.gd")
const ActionExecutorScript := preload("res://src/battle_core/actions/action_executor.gd")
const ActionCastServiceScript := preload("res://src/battle_core/actions/action_cast_service.gd")
const ActionHitResolutionServiceScript := preload("res://src/battle_core/actions/action_hit_resolution_service.gd")
const SwitchActionServiceScript := preload("res://src/battle_core/actions/switch_action_service.gd")
const ActionLogServiceScript := preload("res://src/battle_core/actions/action_log_service.gd")
const TargetResolverScript := preload("res://src/battle_core/actions/target_resolver.gd")
const StatCalculatorScript := preload("res://src/battle_core/math/stat_calculator.gd")
const MpServiceScript := preload("res://src/battle_core/math/mp_service.gd")
const HitServiceScript := preload("res://src/battle_core/math/hit_service.gd")
const DamageServiceScript := preload("res://src/battle_core/math/damage_service.gd")
const CombatTypeServiceScript := preload("res://src/battle_core/math/combat_type_service.gd")
const LeaveServiceScript := preload("res://src/battle_core/lifecycle/leave_service.gd")
const FaintResolverScript := preload("res://src/battle_core/lifecycle/faint_resolver.gd")
const DefaultReplacementSelectorScript := preload("res://src/battle_core/lifecycle/default_replacement_selector.gd")
const ReplacementServiceScript := preload("res://src/battle_core/lifecycle/replacement_service.gd")
const TriggerDispatcherScript := preload("res://src/battle_core/effects/trigger_dispatcher.gd")
const TriggerBatchRunnerScript := preload("res://src/battle_core/effects/trigger_batch_runner.gd")
const EffectQueueServiceScript := preload("res://src/battle_core/effects/effect_queue_service.gd")
const PayloadExecutorScript := preload("res://src/battle_core/effects/payload_executor.gd")
const PayloadNumericHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_numeric_handler.gd")
const PayloadStateHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_state_handler.gd")
const PayloadForcedReplaceHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_forced_replace_handler.gd")
const EffectInstanceServiceScript := preload("res://src/battle_core/effects/effect_instance_service.gd")
const EffectInstanceDispatcherScript := preload("res://src/battle_core/effects/effect_instance_dispatcher.gd")
const RuleModServiceScript := preload("res://src/battle_core/effects/rule_mod_service.gd")
const RuleModValueResolverScript := preload("res://src/battle_core/effects/rule_mod_value_resolver.gd")
const PassiveSkillServiceScript := preload("res://src/battle_core/passives/passive_skill_service.gd")
const PassiveItemServiceScript := preload("res://src/battle_core/passives/passive_item_service.gd")
const FieldServiceScript := preload("res://src/battle_core/passives/field_service.gd")
const FieldApplyServiceScript := preload("res://src/battle_core/passives/field_apply_service.gd")
const BattleLoggerScript := preload("res://src/battle_core/logging/battle_logger.gd")
const LogEventBuilderScript := preload("res://src/battle_core/logging/log_event_builder.gd")
const ReplayRunnerScript := preload("res://src/battle_core/logging/replay_runner.gd")
const BattleCoreManagerScript := preload("res://src/battle_core/facades/battle_core_manager.gd")
const PublicSnapshotBuilderScript := preload("res://src/battle_core/facades/public_snapshot_builder.gd")

const SERVICE_SPECS := [
    {"slot": "id_factory", "script": IdFactoryScript},
    {"slot": "rng_service", "script": RngServiceScript},
    {"slot": "legal_action_service", "script": LegalActionServiceScript},
    {"slot": "command_builder", "script": CommandBuilderScript},
    {"slot": "command_validator", "script": CommandValidatorScript},
    {"slot": "battle_initializer", "script": BattleInitializerScript},
    {"slot": "action_queue_builder", "script": ActionQueueBuilderScript},
    {"slot": "turn_loop_controller", "script": TurnLoopControllerScript},
    {"slot": "turn_resolution_service", "script": TurnResolutionServiceScript},
    {"slot": "turn_selection_resolver", "script": TurnSelectionResolverScript},
    {"slot": "turn_field_lifecycle_service", "script": TurnFieldLifecycleServiceScript},
    {"slot": "battle_result_service", "script": BattleResultServiceScript},
    {"slot": "runtime_guard_service", "script": RuntimeGuardServiceScript},
    {"slot": "action_executor", "script": ActionExecutorScript},
    {"slot": "action_cast_service", "script": ActionCastServiceScript},
    {"slot": "action_hit_resolution_service", "script": ActionHitResolutionServiceScript},
    {"slot": "switch_action_service", "script": SwitchActionServiceScript},
    {"slot": "action_log_service", "script": ActionLogServiceScript},
    {"slot": "target_resolver", "script": TargetResolverScript},
    {"slot": "stat_calculator", "script": StatCalculatorScript},
    {"slot": "mp_service", "script": MpServiceScript},
    {"slot": "hit_service", "script": HitServiceScript},
    {"slot": "damage_service", "script": DamageServiceScript},
    {"slot": "combat_type_service", "script": CombatTypeServiceScript},
    {"slot": "leave_service", "script": LeaveServiceScript},
    {"slot": "faint_resolver", "script": FaintResolverScript},
    {"slot": "replacement_selector", "script": DefaultReplacementSelectorScript},
    {"slot": "replacement_service", "script": ReplacementServiceScript},
    {"slot": "trigger_dispatcher", "script": TriggerDispatcherScript},
    {"slot": "trigger_batch_runner", "script": TriggerBatchRunnerScript},
    {"slot": "effect_queue_service", "script": EffectQueueServiceScript},
    {"slot": "payload_executor", "script": PayloadExecutorScript},
    {"slot": "payload_numeric_handler", "script": PayloadNumericHandlerScript},
    {"slot": "payload_state_handler", "script": PayloadStateHandlerScript},
    {"slot": "payload_forced_replace_handler", "script": PayloadForcedReplaceHandlerScript},
    {"slot": "effect_instance_service", "script": EffectInstanceServiceScript},
    {"slot": "effect_instance_dispatcher", "script": EffectInstanceDispatcherScript},
    {"slot": "rule_mod_service", "script": RuleModServiceScript},
    {"slot": "rule_mod_value_resolver", "script": RuleModValueResolverScript},
    {"slot": "passive_skill_service", "script": PassiveSkillServiceScript},
    {"slot": "passive_item_service", "script": PassiveItemServiceScript},
    {"slot": "field_service", "script": FieldServiceScript},
    {"slot": "field_apply_service", "script": FieldApplyServiceScript},
    {"slot": "battle_logger", "script": BattleLoggerScript},
    {"slot": "log_event_builder", "script": LogEventBuilderScript},
    {"slot": "public_snapshot_builder", "script": PublicSnapshotBuilderScript},
    {"slot": "replay_runner", "script": ReplayRunnerScript},
]

const WIRING_SPECS := [
    {"owner": "command_builder", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "legal_action_service", "dependency": "rule_mod_service", "source": "rule_mod_service"},
    {"owner": "battle_initializer", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "battle_initializer", "dependency": "rng_service", "source": "rng_service"},
    {"owner": "battle_initializer", "dependency": "faint_resolver", "source": "faint_resolver"},
    {"owner": "battle_initializer", "dependency": "field_service", "source": "field_service"},
    {"owner": "battle_initializer", "dependency": "trigger_batch_runner", "source": "trigger_batch_runner"},
    {"owner": "battle_initializer", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "battle_initializer", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "battle_initializer", "dependency": "public_snapshot_builder", "source": "public_snapshot_builder"},
    {"owner": "battle_initializer", "dependency": "combat_type_service", "source": "combat_type_service"},
    {"owner": "battle_initializer", "dependency": "mp_service", "source": "mp_service"},
    {"owner": "battle_initializer", "dependency": "rule_mod_service", "source": "rule_mod_service"},
    {"owner": "action_queue_builder", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "action_queue_builder", "dependency": "rng_service", "source": "rng_service"},
    {"owner": "action_queue_builder", "dependency": "stat_calculator", "source": "stat_calculator"},
    {"owner": "leave_service", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "leave_service", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "replacement_service", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "replacement_service", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "replacement_service", "dependency": "replacement_selector", "source": "replacement_selector"},
    {"owner": "replacement_service", "dependency": "leave_service", "source": "leave_service"},
    {"owner": "replacement_service", "dependency": "trigger_batch_runner", "source": "trigger_batch_runner"},
    {"owner": "replacement_service", "dependency": "field_service", "source": "field_service"},
    {"owner": "faint_resolver", "dependency": "leave_service", "source": "leave_service"},
    {"owner": "faint_resolver", "dependency": "replacement_service", "source": "replacement_service"},
    {"owner": "faint_resolver", "dependency": "passive_skill_service", "source": "passive_skill_service"},
    {"owner": "faint_resolver", "dependency": "passive_item_service", "source": "passive_item_service"},
    {"owner": "faint_resolver", "dependency": "field_service", "source": "field_service"},
    {"owner": "faint_resolver", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
    {"owner": "faint_resolver", "dependency": "effect_instance_dispatcher", "source": "effect_instance_dispatcher"},
    {"owner": "faint_resolver", "dependency": "effect_queue_service", "source": "effect_queue_service"},
    {"owner": "faint_resolver", "dependency": "payload_executor", "source": "payload_executor"},
    {"owner": "faint_resolver", "dependency": "trigger_batch_runner", "source": "trigger_batch_runner"},
    {"owner": "faint_resolver", "dependency": "rng_service", "source": "rng_service"},
    {"owner": "faint_resolver", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "faint_resolver", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "trigger_dispatcher", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "passive_skill_service", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
    {"owner": "passive_item_service", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
    {"owner": "field_service", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
    {"owner": "field_service", "dependency": "trigger_batch_runner", "source": "trigger_batch_runner"},
    {"owner": "field_apply_service", "dependency": "field_service", "source": "field_service"},
    {"owner": "field_apply_service", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
    {"owner": "field_apply_service", "dependency": "trigger_batch_runner", "source": "trigger_batch_runner"},
    {"owner": "field_apply_service", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "field_apply_service", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "field_apply_service", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "field_apply_service", "dependency": "rng_service", "source": "rng_service"},
    {"owner": "trigger_batch_runner", "dependency": "passive_skill_service", "source": "passive_skill_service"},
    {"owner": "trigger_batch_runner", "dependency": "passive_item_service", "source": "passive_item_service"},
    {"owner": "trigger_batch_runner", "dependency": "field_service", "source": "field_service"},
    {"owner": "trigger_batch_runner", "dependency": "effect_instance_dispatcher", "source": "effect_instance_dispatcher"},
    {"owner": "trigger_batch_runner", "dependency": "effect_queue_service", "source": "effect_queue_service"},
    {"owner": "trigger_batch_runner", "dependency": "payload_executor", "source": "payload_executor"},
    {"owner": "trigger_batch_runner", "dependency": "rng_service", "source": "rng_service"},
    {"owner": "effect_instance_service", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "effect_instance_dispatcher", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "rule_mod_service", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "payload_numeric_handler", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "payload_numeric_handler", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "payload_numeric_handler", "dependency": "damage_service", "source": "damage_service"},
    {"owner": "payload_numeric_handler", "dependency": "combat_type_service", "source": "combat_type_service"},
    {"owner": "payload_numeric_handler", "dependency": "stat_calculator", "source": "stat_calculator"},
    {"owner": "payload_numeric_handler", "dependency": "rule_mod_service", "source": "rule_mod_service"},
    {"owner": "payload_numeric_handler", "dependency": "faint_resolver", "source": "faint_resolver"},
    {"owner": "payload_state_handler", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "payload_state_handler", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "payload_state_handler", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "payload_state_handler", "dependency": "effect_instance_service", "source": "effect_instance_service"},
    {"owner": "payload_state_handler", "dependency": "rule_mod_service", "source": "rule_mod_service"},
    {"owner": "payload_state_handler", "dependency": "rule_mod_value_resolver", "source": "rule_mod_value_resolver"},
    {"owner": "payload_state_handler", "dependency": "field_service", "source": "field_service"},
    {"owner": "payload_state_handler", "dependency": "field_apply_service", "source": "field_apply_service"},
    {"owner": "payload_forced_replace_handler", "dependency": "replacement_service", "source": "replacement_service"},
    {"owner": "payload_executor", "dependency": "numeric_payload_handler", "source": "payload_numeric_handler"},
    {"owner": "payload_executor", "dependency": "state_payload_handler", "source": "payload_state_handler"},
    {"owner": "payload_executor", "dependency": "forced_replace_payload_handler", "source": "payload_forced_replace_handler"},
    {"owner": "action_log_service", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "action_log_service", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "action_hit_resolution_service", "dependency": "hit_service", "source": "hit_service"},
    {"owner": "action_hit_resolution_service", "dependency": "rule_mod_service", "source": "rule_mod_service"},
    {"owner": "action_hit_resolution_service", "dependency": "rng_service", "source": "rng_service"},
    {"owner": "action_cast_service", "dependency": "mp_service", "source": "mp_service"},
    {"owner": "action_cast_service", "dependency": "damage_service", "source": "damage_service"},
    {"owner": "action_cast_service", "dependency": "combat_type_service", "source": "combat_type_service"},
    {"owner": "action_cast_service", "dependency": "stat_calculator", "source": "stat_calculator"},
    {"owner": "action_cast_service", "dependency": "rule_mod_service", "source": "rule_mod_service"},
    {"owner": "action_cast_service", "dependency": "action_hit_resolution_service", "source": "action_hit_resolution_service"},
    {"owner": "action_cast_service", "dependency": "target_resolver", "source": "target_resolver"},
    {"owner": "action_cast_service", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
    {"owner": "action_cast_service", "dependency": "effect_queue_service", "source": "effect_queue_service"},
    {"owner": "action_cast_service", "dependency": "payload_executor", "source": "payload_executor"},
    {"owner": "action_cast_service", "dependency": "faint_resolver", "source": "faint_resolver"},
    {"owner": "action_cast_service", "dependency": "trigger_batch_runner", "source": "trigger_batch_runner"},
    {"owner": "action_cast_service", "dependency": "rng_service", "source": "rng_service"},
    {"owner": "action_cast_service", "dependency": "action_log_service", "source": "action_log_service"},
    {"owner": "switch_action_service", "dependency": "leave_service", "source": "leave_service"},
    {"owner": "switch_action_service", "dependency": "action_cast_service", "source": "action_cast_service"},
    {"owner": "switch_action_service", "dependency": "action_log_service", "source": "action_log_service"},
    {"owner": "switch_action_service", "dependency": "field_service", "source": "field_service"},
    {"owner": "action_executor", "dependency": "action_cast_service", "source": "action_cast_service"},
    {"owner": "action_executor", "dependency": "switch_action_service", "source": "switch_action_service"},
    {"owner": "action_executor", "dependency": "action_log_service", "source": "action_log_service"},
    {"owner": "action_executor", "dependency": "rule_mod_service", "source": "rule_mod_service"},
    {"owner": "turn_selection_resolver", "dependency": "legal_action_service", "source": "legal_action_service"},
    {"owner": "turn_selection_resolver", "dependency": "command_builder", "source": "command_builder"},
    {"owner": "turn_selection_resolver", "dependency": "command_validator", "source": "command_validator"},
    {"owner": "turn_field_lifecycle_service", "dependency": "field_service", "source": "field_service"},
    {"owner": "turn_field_lifecycle_service", "dependency": "trigger_batch_runner", "source": "trigger_batch_runner"},
    {"owner": "turn_field_lifecycle_service", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "turn_field_lifecycle_service", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "turn_field_lifecycle_service", "dependency": "battle_result_service", "source": "battle_result_service"},
    {"owner": "turn_resolution_service", "dependency": "selection_resolver", "source": "turn_selection_resolver"},
    {"owner": "turn_resolution_service", "dependency": "field_lifecycle_service", "source": "turn_field_lifecycle_service"},
    {"owner": "turn_resolution_service", "dependency": "mp_service", "source": "mp_service"},
    {"owner": "turn_resolution_service", "dependency": "trigger_batch_runner", "source": "trigger_batch_runner"},
    {"owner": "turn_resolution_service", "dependency": "effect_instance_dispatcher", "source": "effect_instance_dispatcher"},
    {"owner": "turn_resolution_service", "dependency": "rule_mod_service", "source": "rule_mod_service"},
    {"owner": "turn_resolution_service", "dependency": "faint_resolver", "source": "faint_resolver"},
    {"owner": "turn_resolution_service", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "turn_resolution_service", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "turn_resolution_service", "dependency": "battle_result_service", "source": "battle_result_service"},
    {"owner": "battle_result_service", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "battle_result_service", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "battle_result_service", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "turn_loop_controller", "dependency": "action_queue_builder", "source": "action_queue_builder"},
    {"owner": "turn_loop_controller", "dependency": "action_executor", "source": "action_executor"},
    {"owner": "turn_loop_controller", "dependency": "faint_resolver", "source": "faint_resolver"},
    {"owner": "turn_loop_controller", "dependency": "turn_resolution_service", "source": "turn_resolution_service"},
    {"owner": "turn_loop_controller", "dependency": "battle_result_service", "source": "battle_result_service"},
    {"owner": "turn_loop_controller", "dependency": "runtime_guard_service", "source": "runtime_guard_service"},
    {"owner": "turn_loop_controller", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "turn_loop_controller", "dependency": "log_event_builder", "source": "log_event_builder"},
    {"owner": "replay_runner", "dependency": "battle_initializer", "source": "battle_initializer"},
    {"owner": "replay_runner", "dependency": "turn_loop_controller", "source": "turn_loop_controller"},
    {"owner": "replay_runner", "dependency": "battle_logger", "source": "battle_logger"},
    {"owner": "replay_runner", "dependency": "id_factory", "source": "id_factory"},
    {"owner": "replay_runner", "dependency": "rng_service", "source": "rng_service"},
]

const RESET_SPECS := [
    {"owner": "rule_mod_value_resolver", "field": "last_error_code", "value": null},
]

func compose():
    var container = BattleCoreContainerScript.new()
    _instantiate_services(container)
    _wire_dependencies(container)
    container.configure_dispose_specs(_resolve_service_slots(), WIRING_SPECS, RESET_SPECS)
    _assert_container_dependencies(container)
    return container

func compose_manager():
    var manager = BattleCoreManagerScript.new()
    assert(manager != null, "compose_manager requires manager")
    manager.composer = self
    manager.command_id_factory = IdFactoryScript.new()
    manager.command_builder = CommandBuilderScript.new()
    manager.command_builder.id_factory = manager.command_id_factory
    manager.public_snapshot_builder = PublicSnapshotBuilderScript.new()
    return manager

func _assert_container_dependencies(container) -> void:
    for wiring_spec in WIRING_SPECS:
        _assert_dependency(
            container,
            str(wiring_spec["owner"]),
            str(wiring_spec["dependency"])
        )

func _instantiate_services(container) -> void:
    for service_spec in SERVICE_SPECS:
        var slot_name := str(service_spec["slot"])
        var script_ref = service_spec["script"]
        container.set(slot_name, script_ref.new())

func _wire_dependencies(container) -> void:
    for wiring_spec in WIRING_SPECS:
        var owner_name := str(wiring_spec["owner"])
        var dependency_name := str(wiring_spec["dependency"])
        var source_name := str(wiring_spec["source"])
        var owner = container.get(owner_name)
        assert(owner != null, "Composer missing owner: %s" % owner_name)
        owner.set(dependency_name, container.get(source_name))

func _resolve_service_slots() -> PackedStringArray:
    var service_slots := PackedStringArray()
    for service_spec in SERVICE_SPECS:
        service_slots.append(str(service_spec["slot"]))
    return service_slots

func _assert_dependency(container, owner_name: String, dependency_name: String) -> void:
    var owner = container.get(owner_name)
    assert(owner != null, "Composer missing owner: %s" % owner_name)
    assert(owner.get(dependency_name) != null, "%s missing dependency: %s" % [owner_name, dependency_name])
