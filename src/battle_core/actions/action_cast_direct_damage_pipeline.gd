extends RefCounted
class_name ActionCastDirectDamagePipeline

const ActionCastExecuteContractHelperScript := preload("res://src/battle_core/actions/action_cast_execute_contract_helper.gd")
const ActionDamageSegmentResolutionServiceScript := preload("res://src/battle_core/actions/action_damage_segment_resolution_service.gd")
const ActionDamageLogServiceScript := preload("res://src/battle_core/actions/action_damage_log_service.gd")
const ActionDamageSegmentTriggerContextServiceScript := preload("res://src/battle_core/actions/action_damage_segment_trigger_context_service.gd")

var damage_service
var combat_type_service
var stat_calculator
var rule_mod_service
var faint_killer_attribution_service
var action_log_service
var power_bonus_resolver
var trigger_batch_runner

var _segment_resolution_service = ActionDamageSegmentResolutionServiceScript.new()
var _damage_log_service = ActionDamageLogServiceScript.new()
var _segment_trigger_context_service = ActionDamageSegmentTriggerContextServiceScript.new()


func apply_direct_damage(queued_action, actor, target, skill_definition, battle_state, content_index, cause_event_id: String, source_kind_order_active_skill: int) -> Dictionary:
	if target == null:
		return {"invalid_battle_code": null, "resolved_segments": 0}
	if ActionCastExecuteContractHelperScript.should_execute_skill(actor, target, skill_definition):
		_damage_log_service.log_execute_damage(
			queued_action,
			battle_state,
			action_log_service,
			faint_killer_attribution_service,
			actor,
			target,
			cause_event_id,
			source_kind_order_active_skill
		)
		return {"invalid_battle_code": null, "resolved_segments": 0}
	var final_multiplier: float = rule_mod_service.get_final_multiplier(battle_state, actor.unit_instance_id)
	var damage_segments: Array = _segment_resolution_service.resolve_damage_segments(
		skill_definition,
		actor,
		target,
		power_bonus_resolver
	)
	var total_segments := damage_segments.size()
	var resolved_segments := 0
	for segment_index in range(total_segments):
		if not _segment_resolution_service.can_continue_damage_sequence(target):
			break
		var segment_result: Dictionary = _segment_resolution_service.apply_damage_segment(
			queued_action,
			actor,
			target,
			damage_segments[segment_index],
			battle_state,
			damage_service,
			combat_type_service,
			stat_calculator,
			rule_mod_service,
			final_multiplier
		)
		_damage_log_service.log_damage_segment(
			queued_action,
			battle_state,
			action_log_service,
			faint_killer_attribution_service,
			actor,
			target,
			segment_result,
			cause_event_id,
			segment_index + 1,
			total_segments,
			source_kind_order_active_skill
		)
		resolved_segments += 1
		var invalid_code = _segment_trigger_context_service.execute_receive_damage_segment_trigger(
			queued_action,
			battle_state,
			content_index,
			target.unit_instance_id,
			segment_index + 1,
			total_segments,
			String(segment_result.get("segment_combat_type_id", "")),
			trigger_batch_runner
		)
		if invalid_code != null:
			return {
				"invalid_battle_code": invalid_code,
				"resolved_segments": resolved_segments,
			}
	return {
		"invalid_battle_code": null,
		"resolved_segments": resolved_segments,
	}

func apply_default_recoil(queued_action, actor, battle_state, cause_event_id: String, source_kind_order_active_skill: int) -> void:
	var recoil_ratio: float = 0.25
	if battle_state != null:
		recoil_ratio = float(battle_state.default_recoil_ratio)
	var recoil_amount: int = max(1, int(floor(float(actor.max_hp) * recoil_ratio)))
	_damage_log_service.log_default_recoil(
		queued_action,
		actor,
		battle_state,
		action_log_service,
		faint_killer_attribution_service,
		cause_event_id,
		source_kind_order_active_skill,
		recoil_amount
	)
