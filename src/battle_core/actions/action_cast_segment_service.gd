extends RefCounted
class_name ActionCastSegmentService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")
const ActionCastExecuteContractHelperScript := preload("res://src/battle_core/actions/action_cast_execute_contract_helper.gd")
const ActionCastDamageSegmentHelperScript := preload("res://src/battle_core/actions/action_cast_damage_segment_helper.gd")
const ActionDamageSegmentResolutionServiceScript := preload("res://src/battle_core/actions/action_damage_segment_resolution_service.gd")
const ActionDamageLogServiceScript := preload("res://src/battle_core/actions/action_damage_log_service.gd")
const ActionDamageSegmentTriggerContextServiceScript := preload("res://src/battle_core/actions/action_damage_segment_trigger_context_service.gd")
const PowerBonusResolverScript := preload("res://src/battle_core/actions/power_bonus_resolver.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

const COMPOSE_DEPS := [
	{"field": "damage_service", "source": "damage_service"},
	{"field": "combat_type_service", "source": "combat_type_service"},
	{"field": "stat_calculator", "source": "stat_calculator"},
	{"field": "rule_mod_service", "source": "rule_mod_service"},
	{"field": "faint_killer_attribution_service", "source": "faint_killer_attribution_service"},
	{"field": "action_log_service", "source": "action_log_service", "nested": true},
	{"field": "trigger_batch_runner", "source": "trigger_batch_runner", "nested": true},
]

var damage_service: DamageService
var combat_type_service: CombatTypeService
var stat_calculator: StatCalculator
var rule_mod_service: RuleModService
var faint_killer_attribution_service: FaintKillerAttributionService
var action_log_service: ActionLogService
var trigger_batch_runner: TriggerBatchRunner

var power_bonus_resolver: PowerBonusResolver
var _segment_resolution_service = ActionDamageSegmentResolutionServiceScript.new()
var _damage_log_service = ActionDamageLogServiceScript.new()
var _segment_trigger_context_service = ActionDamageSegmentTriggerContextServiceScript.new()

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)

func _compose_post_wire() -> void:
	power_bonus_resolver = PowerBonusResolverScript.new()

func is_damage_action(command: Command, skill_definition) -> bool:
	if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT:
		return true
	return ActionCastDamageSegmentHelperScript.has_damage_truth(skill_definition)

func apply_direct_damage(queued_action: QueuedAction, actor, target, skill_definition, battle_state: BattleState, content_index: BattleContentIndex, cause_event_id: String, source_kind_order_active_skill: int) -> Dictionary:
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
	var final_multiplier_error: Dictionary = rule_mod_service.error_state()
	if final_multiplier_error.get("code", null) != null:
		return {
			"invalid_battle_code": final_multiplier_error.get("code", null),
			"resolved_segments": 0,
		}
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
		if segment_result.get("invalid_battle_code", null) != null:
			return {
				"invalid_battle_code": segment_result.get("invalid_battle_code", null),
				"resolved_segments": resolved_segments,
			}
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

func apply_default_recoil(queued_action: QueuedAction, actor, battle_state: BattleState, cause_event_id: String, source_kind_order_active_skill: int) -> void:
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

func dispatch_receive_action_hit_trigger(resolved_target, battle_state: BattleState, content_index: BattleContentIndex) -> Variant:
	if resolved_target == null:
		return null
	return trigger_batch_runner.execute_trigger_batch(
		ContentSchemaScript.TRIGGER_ON_RECEIVE_ACTION_HIT,
		battle_state,
		content_index,
		[resolved_target.unit_instance_id],
		battle_state.current_chain_context()
	)
