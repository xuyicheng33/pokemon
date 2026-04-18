extends RefCounted
class_name ActionLogService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "battle_logger",
		"source": "battle_logger",
		"nested": true,
	},
	{
		"field": "log_event_builder",
		"source": "log_event_builder",
		"nested": true,
	},
]

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ValueChangeFactoryScript := preload("res://src/battle_core/contracts/value_change_factory.gd")

var battle_logger
var log_event_builder

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func log_action_cancelled_pre_start(queued_action, battle_state, command) -> void:
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.ACTION_CANCELLED_PRE_START,
        battle_state,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": command.actor_id,
            "priority": queued_action.priority,
            "speed_tie_roll": queued_action.speed_tie_roll,
            "trigger_name": "cancelled_pre_start",
            "payload_summary": "%s cancelled before start" % command.command_type,
        }
    ))

func log_action_cast(queued_action, battle_state, command, mp_changes: Array) -> String:
    var log_event = log_event_builder.build_event(
        EventTypesScript.ACTION_CAST,
        battle_state,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": queued_action.target_snapshot.target_unit_id,
            "priority": queued_action.priority,
            "target_slot": queued_action.target_snapshot.target_slot,
            "action_window_passed": true,
            "has_acted": true,
            "speed_tie_roll": queued_action.speed_tie_roll,
            "trigger_name": "on_cast",
            "value_changes": mp_changes,
            "payload_summary": "%s cast" % command.command_type,
        }
    )
    battle_logger.append_event(log_event)
    return log_event_builder.resolve_event_id(log_event)

func log_action_failed_post_start(queued_action, battle_state, command) -> void:
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.ACTION_FAILED_POST_START,
        battle_state,
        {
            "source_instance_id": queued_action.action_id,
            "priority": queued_action.priority,
            "target_slot": queued_action.target_snapshot.target_slot,
            "action_window_passed": true,
            "has_acted": true,
            "speed_tie_roll": queued_action.speed_tie_roll,
            "trigger_name": "action_failed_post_start",
            "payload_summary": "%s failed at execution start" % command.command_type,
        }
    ))

func log_action_miss(queued_action, battle_state, command, target_instance_id: Variant, hit_roll: Variant) -> void:
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.ACTION_MISS,
        battle_state,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": target_instance_id,
            "priority": queued_action.priority,
            "target_slot": queued_action.target_snapshot.target_slot,
            "action_window_passed": true,
            "has_acted": true,
            "speed_tie_roll": queued_action.speed_tie_roll,
            "hit_roll": hit_roll,
            "trigger_name": "on_miss",
            "payload_summary": "%s missed" % command.command_type,
        }
    ))

func log_action_hit(queued_action, battle_state, command, target_instance_id: Variant, hit_roll: Variant) -> String:
    var log_event = log_event_builder.build_event(
        EventTypesScript.ACTION_HIT,
        battle_state,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": target_instance_id,
            "priority": queued_action.priority,
            "target_slot": queued_action.target_snapshot.target_slot,
            "action_window_passed": true,
            "has_acted": true,
            "speed_tie_roll": queued_action.speed_tie_roll,
            "hit_roll": hit_roll,
            "trigger_name": "on_hit",
            "payload_summary": "%s hit" % command.command_type,
        }
    )
    battle_logger.append_event(log_event)
    return log_event_builder.resolve_event_id(log_event)

func log_damage(queued_action, battle_state, actor, target, damage_amount: int, value_change, type_effectiveness: float, cause_event_id: String, segment_index: int = 0, segment_total: int = 0, summary_suffix: String = "") -> Variant:
    var payload_summary := "%s dealt %d damage to %s" % [actor.public_id, damage_amount, target.public_id]
    if segment_index > 0 and segment_total > 0:
        payload_summary += " [segment %d/%d]" % [segment_index, segment_total]
    if not summary_suffix.is_empty():
        payload_summary += " %s" % summary_suffix
    var log_event = log_event_builder.build_effect_event(
        EventTypesScript.EFFECT_DAMAGE,
        battle_state,
        cause_event_id,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": target.unit_instance_id,
            "priority": queued_action.priority,
            "target_slot": queued_action.target_snapshot.target_slot,
            "trigger_name": "on_hit",
            "type_effectiveness": type_effectiveness,
            "value_changes": [value_change],
            "payload_summary": payload_summary,
        }
    )
    battle_logger.append_event(log_event)
    return log_event

func log_recoil(queued_action, battle_state, actor, recoil_amount: int, value_change, cause_event_id: String) -> Variant:
    var log_event = log_event_builder.build_effect_event(
        EventTypesScript.EFFECT_DAMAGE,
        battle_state,
        cause_event_id,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": actor.unit_instance_id,
            "priority": queued_action.priority,
            "trigger_name": "recoil",
            "type_effectiveness": 1.0,
            "value_changes": [value_change],
            "payload_summary": "%s recoil %d" % [actor.public_id, recoil_amount],
        }
    )
    battle_logger.append_event(log_event)
    return log_event

func log_switch_state(queued_action, battle_state, actor, target_unit) -> void:
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.STATE_SWITCH,
        battle_state,
        {
            "source_instance_id": actor.unit_instance_id,
            "target_instance_id": target_unit.unit_instance_id if target_unit != null else null,
            "priority": queued_action.priority,
            "target_slot": ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
            "leave_reason": "manual_switch",
            "trigger_name": "on_switch",
            "payload_summary": "%s switched to %s" % [actor.public_id, target_unit.public_id if target_unit != null else "unknown"],
        }
    ))

func log_state_enter(battle_state, target_unit) -> void:
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.STATE_ENTER,
        battle_state,
        {
            "source_instance_id": target_unit.unit_instance_id,
            "target_instance_id": target_unit.unit_instance_id,
            "target_slot": ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
            "trigger_name": "on_enter",
            "payload_summary": "%s entered battle" % target_unit.public_id,
        }
    ))

func build_value_change(entity_id: String, resource_name: String, before_value: int, after_value: int) -> Variant:
    return ValueChangeFactoryScript.create(entity_id, resource_name, before_value, after_value)

func log_action_resource_change(queued_action, battle_state, actor, resource_name: String, before_value: int, after_value: int, cause_event_id: String, payload_summary: String) -> void:
    if before_value == after_value:
        return
    var value_change = build_value_change(actor.unit_instance_id, resource_name, before_value, after_value)
    battle_logger.append_event(log_event_builder.build_effect_event(
        EventTypesScript.EFFECT_RESOURCE_MOD,
        battle_state,
        cause_event_id,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": actor.unit_instance_id,
            "priority": queued_action.priority,
            "target_slot": queued_action.target_snapshot.target_slot,
            "trigger_name": "on_cast",
            "value_changes": [value_change],
            "payload_summary": payload_summary,
        }
    ))
