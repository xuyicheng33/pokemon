extends RefCounted
class_name FieldTriggerCollectionHelper

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func collect_trigger_events(
	trigger_name: String,
	battle_state: BattleState,
	content_index: BattleContentIndex,
	chain_context: ChainContext,
	trigger_dispatcher,
	source_kind_order_field: int
) -> Dictionary:
	if battle_state.field_state == null:
		return {"events": [], "invalid_code": null}
	var field_definition = get_field_definition_for_state(battle_state.field_state, content_index)
	if field_definition == null:
		return {"events": [], "invalid_code": ErrorCodesScript.INVALID_STATE_CORRUPTION}
	var effect_ids: PackedStringArray = PackedStringArray()
	for effect_id in field_definition.effect_ids:
		var effect_definition = content_index.effects.get(effect_id)
		if effect_definition == null:
			return {"events": [], "invalid_code": ErrorCodesScript.INVALID_EFFECT_DEFINITION}
		if not effect_definition.trigger_names.has(trigger_name):
			continue
		effect_ids.append(effect_id)
	if effect_ids.is_empty():
		return {"events": [], "invalid_code": null}
	var effect_events = trigger_dispatcher.collect_events(
		trigger_name,
		battle_state,
		content_index,
		effect_ids,
		battle_state.field_state.creator,
		battle_state.field_state.instance_id,
		source_kind_order_field,
		battle_state.field_state.source_order_speed_snapshot,
		chain_context
	)
	return {
		"events": effect_events,
		"invalid_code": _read_trigger_dispatcher_invalid_battle_code(trigger_dispatcher),
	}

func collect_lifecycle_effect_events(
	trigger_name: String,
	field_state,
	effect_ids: PackedStringArray,
	battle_state: BattleState,
	content_index: BattleContentIndex,
	chain_context: ChainContext,
	trigger_dispatcher,
	source_kind_order_field: int
) -> Dictionary:
	if field_state == null or content_index == null or effect_ids.is_empty():
		return {"events": [], "invalid_code": null}
	var lifecycle_chain_context = build_lifecycle_chain_context(chain_context, battle_state, field_state.creator)
	var effect_events = trigger_dispatcher.collect_events(
		trigger_name,
		battle_state,
		content_index,
		effect_ids,
		field_state.creator,
		field_state.instance_id,
		source_kind_order_field,
		field_state.source_order_speed_snapshot,
		lifecycle_chain_context
	)
	return {
		"events": effect_events,
		"invalid_code": _read_trigger_dispatcher_invalid_battle_code(trigger_dispatcher),
	}

func get_field_definition_for_state(field_state, content_index: BattleContentIndex) -> Variant:
	if field_state == null or content_index == null:
		return null
	return content_index.fields.get(field_state.field_def_id)

func build_matchup_signature(battle_state: BattleState) -> String:
	var active_ids: Array = []
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		if active_unit == null or active_unit.current_hp <= 0:
			return ""
		active_ids.append(active_unit.unit_instance_id)
	active_ids.sort()
	return "|".join(PackedStringArray(active_ids))

func resolve_opponent_active_id_for_creator(battle_state: BattleState, creator_id: String) -> Variant:
	if creator_id.is_empty():
		return null
	var side_state = battle_state.get_side_for_unit(creator_id)
	if side_state == null:
		return null
	var opponent_side = battle_state.get_opponent_side(side_state.side_id)
	if opponent_side == null:
		return null
	var target_unit = opponent_side.get_active_unit(ContentSchemaScript.ACTIVE_SLOT_PRIMARY)
	if target_unit == null or target_unit.current_hp <= 0:
		return null
	return target_unit.unit_instance_id

func build_lifecycle_chain_context(chain_context: ChainContext, battle_state: BattleState, creator_id: String) -> Variant:
	if chain_context == null:
		return null
	var lifecycle_chain_context = chain_context.copy_shallow()
	lifecycle_chain_context.actor_id = creator_id
	lifecycle_chain_context.target_slot = ContentSchemaScript.ACTIVE_SLOT_PRIMARY
	lifecycle_chain_context.target_unit_id = resolve_opponent_active_id_for_creator(battle_state, creator_id)
	return lifecycle_chain_context

func _read_trigger_dispatcher_invalid_battle_code(trigger_dispatcher) -> Variant:
	if trigger_dispatcher == null:
		return null
	return trigger_dispatcher.invalid_battle_code()
