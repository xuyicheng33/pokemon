extends RefCounted
class_name TurnStartRegenService

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ValueChangeFactoryScript := preload("res://src/battle_core/contracts/value_change_factory.gd")

var mp_service: MpService
var rule_mod_service: RuleModService
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder

func apply_turn_start_regen(battle_state: BattleState, cause_event_id: String) -> Variant:
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		if active_unit == null or active_unit.current_hp <= 0:
			continue
		var before_mp: int = active_unit.current_mp
		var regen_value: int = rule_mod_service.resolve_mp_regen_value(
			battle_state,
			active_unit.unit_instance_id,
			active_unit.regen_per_turn
		)
		var rule_error: Dictionary = rule_mod_service.error_state()
		if rule_error.get("code", null) != null:
			return rule_error.get("code", null)
		active_unit.current_mp = mp_service.apply_turn_start_regen(
			active_unit.current_mp,
			regen_value,
			active_unit.max_mp
		)
		if before_mp == active_unit.current_mp:
			continue
		var value_change = ValueChangeFactoryScript.create(
			active_unit.unit_instance_id,
			"mp",
			before_mp,
			active_unit.current_mp
		)
		var log_event = log_event_builder.build_effect_event(
			EventTypesScript.EFFECT_RESOURCE_MOD,
			battle_state,
			cause_event_id,
			{
				"source_instance_id": "system:turn_start",
				"target_instance_id": active_unit.unit_instance_id,
				"trigger_name": "turn_start",
				"value_changes": [value_change],
				"payload_summary": "%s regenerated %d mp" % [active_unit.public_id, value_change.delta],
			}
		)
		battle_logger.append_event(log_event)
	return null
