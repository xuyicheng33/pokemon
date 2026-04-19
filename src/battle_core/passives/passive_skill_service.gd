extends RefCounted
class_name PassiveSkillService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "trigger_dispatcher",
		"source": "trigger_dispatcher",
		"nested": true,
	},
]

const SOURCE_KIND_ORDER_PASSIVE_SKILL := 3
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var trigger_dispatcher: TriggerDispatcher
var last_invalid_battle_code: Variant = null

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func collect_trigger_events(trigger_name: String, battle_state, content_index, owner_unit_ids: Array, chain_context) -> Array:
	last_invalid_battle_code = null
	var effect_events: Array = []
	for owner_id in owner_unit_ids:
		var owner_unit = battle_state.get_unit(owner_id)
		if owner_unit == null:
			last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
			return []
		var unit_definition = content_index.units.get(owner_unit.definition_id)
		if unit_definition == null:
			last_invalid_battle_code = ErrorCodesScript.INVALID_CONTENT_SNAPSHOT
			return []
		if unit_definition.passive_skill_id.is_empty():
			continue
		var passive_definition = content_index.passive_skills.get(unit_definition.passive_skill_id)
		if passive_definition == null:
			last_invalid_battle_code = ErrorCodesScript.INVALID_CONTENT_SNAPSHOT
			return []
		if not passive_definition.trigger_names.has(trigger_name):
			continue
		if passive_definition.effect_ids.is_empty():
			continue
		var source_speed_snapshot: int = owner_unit.last_effective_speed if owner_unit.last_effective_speed > 0 else owner_unit.base_speed
		var source_instance_id: String = "passive_skill:%s:%s" % [owner_unit.unit_instance_id, passive_definition.id]
		var triggered_events: Array = trigger_dispatcher.collect_events(
			trigger_name,
			battle_state,
			content_index,
			passive_definition.effect_ids,
			owner_unit.unit_instance_id,
			source_instance_id,
			SOURCE_KIND_ORDER_PASSIVE_SKILL,
			source_speed_snapshot,
			chain_context
		)
		last_invalid_battle_code = _read_trigger_dispatcher_invalid_battle_code()
		if last_invalid_battle_code != null:
			return []
		effect_events.append_array(triggered_events)
	return effect_events

func _read_trigger_dispatcher_invalid_battle_code() -> Variant:
	if trigger_dispatcher == null:
		return null
	return trigger_dispatcher.invalid_battle_code()
