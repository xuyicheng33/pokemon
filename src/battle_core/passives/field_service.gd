extends RefCounted
class_name FieldService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "trigger_dispatcher",
		"source": "trigger_dispatcher",
		"nested": true,
	},
]

const SOURCE_KIND_ORDER_FIELD := 1
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const FieldTriggerCollectionHelperScript := preload("res://src/battle_core/passives/field_trigger_collection_helper.gd")
const FieldCleanupHelperScript := preload("res://src/battle_core/passives/field_cleanup_helper.gd")

var trigger_dispatcher: TriggerDispatcher
var last_invalid_battle_code: Variant = null

var _trigger_helper = FieldTriggerCollectionHelperScript.new()
var _cleanup_helper = FieldCleanupHelperScript.new()

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func collect_trigger_events(trigger_name: String, battle_state: BattleState, content_index: BattleContentIndex, chain_context: ChainContext) -> Array:
	last_invalid_battle_code = null
	var result: Dictionary = _trigger_helper.collect_trigger_events(
		trigger_name,
		battle_state,
		content_index,
		chain_context,
		trigger_dispatcher,
		SOURCE_KIND_ORDER_FIELD
	)
	last_invalid_battle_code = result.get("invalid_code", null)
	return result.get("events", [])

func get_field_definition_for_state(field_state, content_index: BattleContentIndex) -> Variant:
	return _trigger_helper.get_field_definition_for_state(field_state, content_index)

func collect_lifecycle_effect_events(trigger_name: String, field_state, effect_ids: PackedStringArray, battle_state: BattleState, content_index: BattleContentIndex, chain_context: ChainContext) -> Array:
	last_invalid_battle_code = null
	var result: Dictionary = _trigger_helper.collect_lifecycle_effect_events(
		trigger_name,
		field_state,
		effect_ids,
		battle_state,
		content_index,
		chain_context,
		trigger_dispatcher,
		SOURCE_KIND_ORDER_FIELD
	)
	last_invalid_battle_code = result.get("invalid_code", null)
	return result.get("events", [])

func break_field_if_creator_inactive(
	battle_state: BattleState,
	content_index: BattleContentIndex,
	chain_context: ChainContext,
	execute_trigger_batch: Callable = Callable()
) -> Variant:
	if battle_state.field_state == null:
		return null
	var creator_id := String(battle_state.field_state.creator)
	if creator_id.is_empty():
		return ErrorCodesScript.INVALID_STATE_CORRUPTION
	var creator_unit = battle_state.get_unit(creator_id)
	if creator_unit != null and creator_unit.current_hp > 0 and creator_unit.leave_state == LeaveStatesScript.ACTIVE:
		return null
	return break_active_field(
		battle_state,
		content_index,
		"field_break",
		chain_context,
		execute_trigger_batch
	)

func break_active_field(
	battle_state: BattleState,
	content_index: BattleContentIndex,
	trigger_name: String,
	chain_context: ChainContext,
	execute_trigger_batch: Callable = Callable()
) -> Variant:
	if battle_state.field_state == null:
		return null
	var current_field_state = battle_state.field_state
	var field_definition = get_field_definition_for_state(current_field_state, content_index)
	if field_definition == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return ErrorCodesScript.INVALID_STATE_CORRUPTION
	if not field_definition.on_break_effect_ids.is_empty():
		var break_events: Array = collect_lifecycle_effect_events(
			trigger_name,
			current_field_state,
			field_definition.on_break_effect_ids,
			battle_state,
			content_index,
			chain_context
		)
		if not break_events.is_empty():
			if not execute_trigger_batch.is_valid():
				last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
				return ErrorCodesScript.INVALID_STATE_CORRUPTION
			var break_invalid_code = execute_trigger_batch.call(
				"__field_break__",
				battle_state,
				content_index,
				[],
				chain_context,
				break_events
			)
			if break_invalid_code != null:
				return break_invalid_code
	_cleanup_helper.clear_old_field_if_still_active(battle_state, current_field_state)
	return null

func tick_turn_end(field_state) -> bool:
	if field_state == null:
		return false
	field_state.remaining_turns -= 1
	return field_state.remaining_turns <= 0

func build_matchup_signature(battle_state: BattleState) -> String:
	return _trigger_helper.build_matchup_signature(battle_state)

func resolve_opponent_active_id_for_creator(battle_state: BattleState, creator_id: String) -> Variant:
	return _trigger_helper.resolve_opponent_active_id_for_creator(battle_state, creator_id)

func clear_field_state_if_matches(battle_state: BattleState, field_state) -> void:
	_cleanup_helper.clear_field_state_if_matches(battle_state, field_state)
