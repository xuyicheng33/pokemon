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
var action_hit_resolution_service
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
var field_apply_service
var battle_logger
var log_event_builder
var public_snapshot_builder
var replay_runner

var _dispose_service_slots: PackedStringArray = PackedStringArray()
var _dispose_wiring_specs: Array = []
var _dispose_reset_specs: Array = []

func configure_dispose_specs(service_slots: PackedStringArray, wiring_specs: Array, reset_specs: Array = []) -> void:
    _dispose_service_slots = service_slots.duplicate()
    _dispose_wiring_specs = wiring_specs.duplicate(true)
    _dispose_reset_specs = reset_specs.duplicate(true)

func dispose() -> void:
    for wiring_spec in _dispose_wiring_specs:
        var owner_name := str(wiring_spec.get("owner", ""))
        var dependency_name := str(wiring_spec.get("dependency", ""))
        if owner_name.is_empty() or dependency_name.is_empty():
            continue
        var owner = get(owner_name)
        if owner != null:
            owner.set(dependency_name, null)
    for reset_spec in _dispose_reset_specs:
        var owner_name := str(reset_spec.get("owner", ""))
        var field_name := str(reset_spec.get("field", ""))
        if owner_name.is_empty() or field_name.is_empty():
            continue
        var owner = get(owner_name)
        if owner != null:
            owner.set(field_name, reset_spec.get("value", null))
    for slot_name in _dispose_service_slots:
        set(slot_name, null)
    _dispose_service_slots = PackedStringArray()
    _dispose_wiring_specs.clear()
    _dispose_reset_specs.clear()
