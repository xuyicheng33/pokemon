extends RefCounted
class_name ActionDamageLogService

func log_damage_segment(
	queued_action,
	battle_state,
	action_log_service,
	faint_killer_attribution_service,
	actor,
	target,
	segment_result: Dictionary,
	cause_event_id: String,
	segment_index: int,
	total_segments: int,
	source_kind_order_active_skill: int
) -> void:
	var before_hp: int = int(segment_result.get("before_hp", target.current_hp))
	var value_change = action_log_service.build_value_change(target.unit_instance_id, "hp", before_hp, target.current_hp)
	var log_event = action_log_service.log_damage(
		queued_action,
		battle_state,
		actor,
		target,
		int(segment_result.get("damage_amount", 0)),
		value_change,
		float(segment_result.get("type_effectiveness", 1.0)),
		cause_event_id,
		segment_index,
		total_segments
	)
	_record_fatal_damage(
		battle_state,
		faint_killer_attribution_service,
		target.unit_instance_id,
		before_hp,
		target.current_hp,
		actor.unit_instance_id,
		queued_action.action_id,
		queued_action.priority,
		queued_action.speed_snapshot,
		int(log_event.event_step_id) if log_event != null else 0,
		source_kind_order_active_skill
	)

func log_execute_damage(
	queued_action,
	battle_state,
	action_log_service,
	faint_killer_attribution_service,
	actor,
	target,
	cause_event_id: String,
	source_kind_order_active_skill: int
) -> void:
	var before_hp: int = target.current_hp
	target.current_hp = 0
	var value_change = action_log_service.build_value_change(target.unit_instance_id, "hp", before_hp, target.current_hp)
	var log_event = action_log_service.log_damage(
		queued_action,
		battle_state,
		actor,
		target,
		before_hp,
		value_change,
		1.0,
		cause_event_id,
		0,
		0,
		"[execute]"
	)
	_record_fatal_damage(
		battle_state,
		faint_killer_attribution_service,
		target.unit_instance_id,
		before_hp,
		target.current_hp,
		actor.unit_instance_id,
		queued_action.action_id,
		queued_action.priority,
		queued_action.speed_snapshot,
		int(log_event.event_step_id) if log_event != null else 0,
		source_kind_order_active_skill
	)

func log_default_recoil(
	queued_action,
	actor,
	battle_state,
	action_log_service,
	faint_killer_attribution_service,
	cause_event_id: String,
	source_kind_order_active_skill: int,
	recoil_amount: int
) -> void:
	var before_hp: int = actor.current_hp
	actor.current_hp = clamp(actor.current_hp - recoil_amount, 0, actor.max_hp)
	var value_change = action_log_service.build_value_change(actor.unit_instance_id, "hp", before_hp, actor.current_hp)
	var log_event = action_log_service.log_recoil(queued_action, battle_state, actor, recoil_amount, value_change, cause_event_id)
	_record_fatal_damage(
		battle_state,
		faint_killer_attribution_service,
		actor.unit_instance_id,
		before_hp,
		actor.current_hp,
		actor.unit_instance_id,
		queued_action.action_id,
		queued_action.priority,
		queued_action.speed_snapshot,
		int(log_event.event_step_id) if log_event != null else 0,
		source_kind_order_active_skill
	)

func _record_fatal_damage(
	battle_state,
	faint_killer_attribution_service,
	target_unit_id: String,
	before_hp: int,
	after_hp: int,
	killer_unit_id: Variant,
	source_instance_id: String,
	priority: int,
	source_order_speed_snapshot: int,
	cause_event_step_id: int,
	source_kind_order_active_skill: int
) -> void:
	if faint_killer_attribution_service == null:
		return
	faint_killer_attribution_service.record_fatal_damage(
		battle_state,
		target_unit_id,
		before_hp,
		after_hp,
		killer_unit_id,
		source_instance_id,
		source_kind_order_active_skill,
		source_order_speed_snapshot,
		priority,
		cause_event_step_id
	)
