extends RefCounted
class_name BattleCoreServiceSpecs

const PayloadServiceSpecsScript := preload("res://src/composition/battle_core_payload_service_specs.gd")

const SERVICE_DESCRIPTORS := [
	{"slot": "id_factory", "script": preload("res://src/shared/id_factory.gd")},
	{"slot": "rng_service", "script": preload("res://src/shared/rng_service.gd")},
	{"slot": "content_snapshot_cache", "script": preload("res://src/battle_core/content/content_snapshot_cache.gd")},
	{"slot": "legal_action_service", "script": preload("res://src/battle_core/commands/legal_action_service.gd")},
	{"slot": "domain_legality_service", "script": preload("res://src/battle_core/commands/domain_legality_service.gd")},
	{"slot": "command_builder", "script": preload("res://src/battle_core/commands/command_builder.gd")},
	{"slot": "command_validator", "script": preload("res://src/battle_core/commands/command_validator.gd")},
	{"slot": "battle_initializer", "script": preload("res://src/battle_core/turn/battle_initializer.gd")},
	{"slot": "battle_initializer_setup_validator", "script": preload("res://src/battle_core/turn/battle_initializer_setup_validator.gd")},
	{"slot": "action_queue_builder", "script": preload("res://src/battle_core/turn/action_queue_builder.gd")},
	{"slot": "turn_loop_controller", "script": preload("res://src/battle_core/turn/turn_loop_controller.gd")},
	{"slot": "turn_selection_resolver", "script": preload("res://src/battle_core/turn/turn_selection_resolver.gd")},
	{"slot": "turn_start_phase_service", "script": preload("res://src/battle_core/turn/turn_start_phase_service.gd")},
	{"slot": "turn_end_phase_service", "script": preload("res://src/battle_core/turn/turn_end_phase_service.gd")},
	{"slot": "turn_field_lifecycle_service", "script": preload("res://src/battle_core/turn/turn_field_lifecycle_service.gd")},
	{"slot": "turn_limit_scoring_service", "script": preload("res://src/battle_core/turn/turn_limit_scoring_service.gd")},
	{"slot": "battle_result_service", "script": preload("res://src/battle_core/turn/battle_result_service.gd")},
	{"slot": "runtime_guard_service", "script": preload("res://src/battle_core/turn/runtime_guard_service.gd")},
	{"slot": "action_executor", "script": preload("res://src/battle_core/actions/action_executor.gd")},
	{"slot": "action_chain_context_builder", "script": preload("res://src/battle_core/actions/action_chain_context_builder.gd")},
	{"slot": "action_start_phase_service", "script": preload("res://src/battle_core/actions/action_start_phase_service.gd")},
	{"slot": "action_skill_effect_service", "script": preload("res://src/battle_core/actions/action_skill_effect_service.gd")},
	{"slot": "action_execution_resolution_service", "script": preload("res://src/battle_core/actions/action_execution_resolution_service.gd")},
	{"slot": "action_domain_guard", "script": preload("res://src/battle_core/actions/action_domain_guard.gd")},
	{"slot": "action_cast_service", "script": preload("res://src/battle_core/actions/action_cast_service.gd")},
	{"slot": "action_cast_direct_damage_pipeline", "script": preload("res://src/battle_core/actions/action_cast_direct_damage_pipeline.gd")},
	{"slot": "action_cast_skill_effect_dispatch_pipeline", "script": preload("res://src/battle_core/actions/action_cast_skill_effect_dispatch_pipeline.gd")},
	{"slot": "action_hit_resolution_service", "script": preload("res://src/battle_core/actions/action_hit_resolution_service.gd")},
	{"slot": "power_bonus_resolver", "script": preload("res://src/battle_core/actions/power_bonus_resolver.gd")},
	{"slot": "switch_action_service", "script": preload("res://src/battle_core/actions/switch_action_service.gd")},
	{"slot": "action_log_service", "script": preload("res://src/battle_core/actions/action_log_service.gd")},
	{"slot": "target_resolver", "script": preload("res://src/battle_core/actions/target_resolver.gd")},
	{"slot": "stat_calculator", "script": preload("res://src/battle_core/math/stat_calculator.gd")},
	{"slot": "mp_service", "script": preload("res://src/battle_core/math/mp_service.gd")},
	{"slot": "hit_service", "script": preload("res://src/battle_core/math/hit_service.gd")},
	{"slot": "damage_service", "script": preload("res://src/battle_core/math/damage_service.gd")},
	{"slot": "combat_type_service", "script": preload("res://src/battle_core/math/combat_type_service.gd")},
	{"slot": "leave_service", "script": preload("res://src/battle_core/lifecycle/leave_service.gd")},
	{"slot": "lifecycle_retention_policy", "script": preload("res://src/battle_core/lifecycle/lifecycle_retention_policy.gd")},
	{"slot": "faint_resolver", "script": preload("res://src/battle_core/lifecycle/faint_resolver.gd")},
	{"slot": "faint_killer_attribution_service", "script": preload("res://src/battle_core/lifecycle/faint_killer_attribution_service.gd")},
	{"slot": "faint_leave_replacement_service", "script": preload("res://src/battle_core/lifecycle/faint_leave_replacement_service.gd")},
	{"slot": "replacement_selector", "script": preload("res://src/battle_core/lifecycle/default_replacement_selector.gd")},
	{"slot": "replacement_service", "script": preload("res://src/battle_core/lifecycle/replacement_service.gd")},
	{"slot": "trigger_dispatcher", "script": preload("res://src/battle_core/effects/trigger_dispatcher.gd")},
	{"slot": "trigger_batch_runner", "script": preload("res://src/battle_core/effects/trigger_batch_runner.gd")},
	{"slot": "effect_queue_service", "script": preload("res://src/battle_core/effects/effect_queue_service.gd")},
	{"slot": "effect_precondition_service", "script": preload("res://src/battle_core/effects/effect_precondition_service.gd")},
	{"slot": "payload_executor", "script": preload("res://src/battle_core/effects/payload_executor.gd")},
	{"slot": "effect_instance_service", "script": preload("res://src/battle_core/effects/effect_instance_service.gd")},
	{"slot": "effect_instance_dispatcher", "script": preload("res://src/battle_core/effects/effect_instance_dispatcher.gd")},
	{"slot": "rule_mod_service", "script": preload("res://src/battle_core/effects/rule_mod_service.gd")},
	{"slot": "rule_mod_value_resolver", "script": preload("res://src/battle_core/effects/rule_mod_value_resolver.gd")},
	{"slot": "passive_skill_service", "script": preload("res://src/battle_core/passives/passive_skill_service.gd")},
	{"slot": "passive_item_service", "script": preload("res://src/battle_core/passives/passive_item_service.gd")},
	{"slot": "field_service", "script": preload("res://src/battle_core/passives/field_service.gd")},
	{"slot": "field_apply_service", "script": preload("res://src/battle_core/passives/field_apply_service.gd")},
	{"slot": "domain_clash_orchestrator", "script": preload("res://src/battle_core/passives/domain_clash_orchestrator.gd")},
	{"slot": "field_apply_context_resolver", "script": preload("res://src/battle_core/passives/field_apply_context_resolver.gd")},
	{"slot": "field_apply_conflict_service", "script": preload("res://src/battle_core/passives/field_apply_conflict_service.gd")},
	{"slot": "field_apply_log_service", "script": preload("res://src/battle_core/passives/field_apply_log_service.gd")},
	{"slot": "field_apply_effect_runner", "script": preload("res://src/battle_core/passives/field_apply_effect_runner.gd")},
	{"slot": "battle_logger", "script": preload("res://src/battle_core/logging/battle_logger.gd")},
	{"slot": "log_event_builder", "script": preload("res://src/battle_core/logging/log_event_builder.gd")},
	{"slot": "public_snapshot_builder", "script": preload("res://src/battle_core/facades/public_snapshot_builder.gd")},
	{"slot": "replay_runner", "script": preload("res://src/battle_core/logging/replay_runner.gd")},
]

static func payload_service_descriptors() -> Array:
	return PayloadServiceSpecsScript.service_descriptors()

static func all_service_descriptors() -> Array:
	return SERVICE_DESCRIPTORS + payload_service_descriptors()

static func service_slots() -> PackedStringArray:
	var slots := PackedStringArray()
	for descriptor in all_service_descriptors():
		slots.append(String(descriptor.get("slot", "")))
	return slots

static func script_by_slot(slot_name: String):
	for descriptor in all_service_descriptors():
		if String(descriptor.get("slot", "")) == slot_name:
			return descriptor.get("script", null)
	return null
