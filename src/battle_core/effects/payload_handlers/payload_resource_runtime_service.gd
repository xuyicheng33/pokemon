extends RefCounted
class_name PayloadResourceRuntimeService

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
	{
		"field": "target_helper",
		"source": "payload_unit_target_helper",
		"nested": true,
	},
	{
		"field": "effect_event_helper",
		"source": "payload_effect_event_helper",
		"nested": true,
	},
	{
		"field": "rule_mod_service",
		"source": "rule_mod_service",
		"nested": true,
	},
]

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ValueChangeFactoryScript := preload("res://src/battle_core/contracts/value_change_factory.gd")

var battle_logger
var log_event_builder
var target_helper
var effect_event_helper
var rule_mod_service

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func apply_heal_payload(payload, effect_definition, effect_event, battle_state) -> void:
	var target_unit = target_helper.resolve_target_unit(effect_definition.scope, effect_event, battle_state)
	if not target_helper.is_effect_target_valid(target_unit, effect_definition.scope, effect_event):
		return
	var resolved_amount: int = int(payload.amount)
	if bool(payload.use_percent):
		var percent_base := int(target_unit.max_hp)
		if String(payload.percent_base) == "missing_hp":
			percent_base = max(0, int(target_unit.max_hp) - int(target_unit.current_hp))
		if percent_base <= 0:
			resolved_amount = 0
		else:
			resolved_amount = max(1, int(floor(float(percent_base) * float(payload.percent) / 100.0)))
	var incoming_heal_multiplier: float = rule_mod_service.resolve_incoming_heal_final_multiplier(
		battle_state,
		target_unit.unit_instance_id
	)
	resolved_amount = max(0, int(floor(float(resolved_amount) * incoming_heal_multiplier)))
	_apply_resource_like_change(
		battle_state,
		effect_event,
		target_unit,
		"hp",
		resolved_amount,
		EventTypesScript.EFFECT_HEAL,
		"heal",
		target_unit.max_hp
	)

func apply_resource_mod_payload(payload, effect_definition, effect_event, battle_state) -> void:
	var target_unit = target_helper.resolve_target_unit(effect_definition.scope, effect_event, battle_state)
	if not target_helper.is_effect_target_valid(target_unit, effect_definition.scope, effect_event):
		return
	_apply_resource_like_change(
		battle_state,
		effect_event,
		target_unit,
		String(payload.resource_key),
		int(payload.amount),
		EventTypesScript.EFFECT_RESOURCE_MOD,
		"mp",
		target_unit.max_mp
	)

func _apply_resource_like_change(battle_state, effect_event, target_unit, resource_name: String, delta: int, event_type: String, summary_tag: String, max_value: int) -> void:
	if delta == 0:
		return
	var before_value: int = _read_resource_value(target_unit, resource_name)
	var after_value: int = clamp(before_value + delta, 0, max_value)
	if before_value == after_value:
		return
	_write_resource_value(target_unit, resource_name, after_value)
	var value_change = _build_value_change(target_unit.unit_instance_id, resource_name, before_value, after_value)
	battle_logger.append_event(log_event_builder.build_event(
		event_type,
		battle_state,
		{
			"source_instance_id": effect_event.source_instance_id,
			"target_instance_id": target_unit.unit_instance_id,
			"priority": effect_event.priority,
			"trigger_name": effect_event.trigger_name,
			"cause_event_id": effect_event.event_id,
			"effect_roll": effect_event_helper.resolve_effect_roll(effect_event),
			"value_changes": [value_change],
			"payload_summary": "%s %s %+d" % [target_unit.public_id, summary_tag, value_change.delta],
		}
	))

func _read_resource_value(target_unit, resource_name: String) -> int:
	match resource_name:
		"hp":
			return int(target_unit.current_hp)
		"mp":
			return int(target_unit.current_mp)
		_:
			return int(target_unit.get(resource_name))

func _write_resource_value(target_unit, resource_name: String, value: int) -> void:
	match resource_name:
		"hp":
			target_unit.current_hp = value
		"mp":
			target_unit.current_mp = value
		_:
			target_unit.set(resource_name, value)

func _build_value_change(entity_id: String, resource_name: String, before_value: int, after_value: int) -> Variant:
	return ValueChangeFactoryScript.create(entity_id, resource_name, before_value, after_value)
