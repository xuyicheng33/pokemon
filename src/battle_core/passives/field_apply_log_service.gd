extends RefCounted
class_name FieldApplyLogService

const EventTypesScript := preload("res://src/shared/event_types.gd")
const FieldChangeScript := preload("res://src/battle_core/contracts/field_change.gd")

var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var context_resolver: FieldApplyContextResolver

func log_field_clash(clash_result, before_field, payload, effect_event: EffectEvent, battle_state: BattleState) -> void:
	if clash_result == null or bool(clash_result.same_creator):
		return
	var challenger_creator: String = clash_result.challenger_creator
	var incumbent_creator: String = clash_result.incumbent_creator
	var challenger_won: bool = clash_result.challenger_won
	var winner_creator: String = challenger_creator if challenger_won else incumbent_creator
	var winner_public_id: String = context_resolver.resolve_public_id_or_system(battle_state, winner_creator)
	var payload_summary: String = "field clash %s(%d) vs %s(%d) -> %s keeps field %s" % [
		payload.field_definition_id,
		int(clash_result.challenger_mp),
		before_field.field_def_id,
		int(clash_result.incumbent_mp),
		winner_public_id,
		payload.field_definition_id if challenger_won else before_field.field_def_id,
	]
	battle_logger.append_event(log_event_builder.build_effect_event(
		EventTypesScript.EFFECT_FIELD_CLASH,
		battle_state,
		effect_event.event_id,
		{
			"source_instance_id": effect_event.source_instance_id,
			"target_instance_id": before_field.instance_id,
			"priority": effect_event.priority,
			"trigger_name": effect_event.trigger_name,
			"effect_roll": clash_result.tie_roll,
			"payload_summary": payload_summary,
		}
	))

func log_field_blocked_by_active_domain(before_field, payload, effect_event: EffectEvent, battle_state: BattleState) -> void:
	var active_creator_public_id: String = context_resolver.resolve_public_id_or_system(battle_state, String(before_field.creator))
	battle_logger.append_event(log_event_builder.build_effect_event(
		EventTypesScript.EFFECT_FIELD_BLOCKED,
		battle_state,
		effect_event.event_id,
		{
			"source_instance_id": effect_event.source_instance_id,
			"target_instance_id": before_field.instance_id,
			"priority": effect_event.priority,
			"trigger_name": effect_event.trigger_name,
			"effect_roll": null,
			"payload_summary": "active domain %s by %s blocked field %s" % [
				before_field.field_def_id,
				active_creator_public_id,
				payload.field_definition_id,
			],
		}
	))

func log_apply_field(before_field, field_state, effect_event: EffectEvent, battle_state: BattleState) -> void:
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.EFFECT_APPLY_FIELD,
		battle_state,
		{
			"source_instance_id": effect_event.source_instance_id,
			"priority": effect_event.priority,
			"trigger_name": effect_event.trigger_name,
			"cause_event_id": effect_event.event_id,
			"effect_roll": effect_event.sort_random_roll,
			"field_change": _build_apply_field_change(before_field, field_state),
			"payload_summary": "field -> %s" % field_state.field_def_id,
		}
	))

func _build_apply_field_change(before_field, field_state) -> Variant:
	var field_change = FieldChangeScript.new()
	field_change.change_kind = "apply"
	field_change.before_field_id = before_field.field_def_id if before_field != null else null
	field_change.after_field_id = field_state.field_def_id
	field_change.before_remaining_turns = before_field.remaining_turns if before_field != null else null
	field_change.after_remaining_turns = field_state.remaining_turns
	return field_change
