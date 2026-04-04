extends RefCounted
class_name EffectPreconditionService

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EffectSourceMetaHelperScript := preload("res://src/battle_core/effects/effect_source_meta_helper.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return ""

func passes_effect_preconditions(effect_definition, effect_event, battle_state) -> bool:
	last_invalid_battle_code = null
	if not _passes_incoming_action_filters(effect_definition, effect_event):
		return false
	if effect_definition == null or effect_definition.required_target_effects.is_empty():
		return true
	if effect_definition.scope != "target":
		last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
		return false
	var target_unit = _resolve_required_target(effect_event, battle_state)
	if not _is_required_target_valid(target_unit):
		return false
	var require_same_owner: bool = bool(effect_definition.required_target_same_owner)
	var required_owner_id := String(effect_event.owner_id if effect_event != null else "")
	for required_effect_id in effect_definition.required_target_effects:
		if not _target_has_required_effect(target_unit, String(required_effect_id), require_same_owner, required_owner_id):
			return false
	return true

func _passes_incoming_action_filters(effect_definition, effect_event) -> bool:
	var command_filters: PackedStringArray = effect_definition.required_incoming_command_types
	var combat_type_filters: PackedStringArray = effect_definition.required_incoming_combat_type_ids
	if command_filters.is_empty() and combat_type_filters.is_empty():
		return true
	if effect_event == null or effect_event.chain_context == null:
		return false
	var chain_context = effect_event.chain_context
	var incoming_command_type := String(chain_context.command_type if chain_context.command_type != null else "")
	var incoming_combat_type_id := String(chain_context.action_combat_type_id if chain_context.action_combat_type_id != null else "")
	if not command_filters.is_empty() and not command_filters.has(incoming_command_type):
		return false
	if not combat_type_filters.is_empty() and not combat_type_filters.has(incoming_combat_type_id):
		return false
	return true

func _resolve_required_target(effect_event, battle_state):
	if effect_event == null or effect_event.chain_context == null:
		return null
	var target_unit_id := str(effect_event.chain_context.target_unit_id)
	if target_unit_id.is_empty():
		return null
	return battle_state.get_unit(target_unit_id)

func _is_required_target_valid(target_unit) -> bool:
	return target_unit != null and target_unit.leave_state == LeaveStatesScript.ACTIVE and target_unit.current_hp > 0

func _target_has_required_effect(target_unit, effect_definition_id: String, require_same_owner: bool, required_owner_id: String) -> bool:
	for effect_instance in target_unit.effect_instances:
		if effect_instance.def_id != effect_definition_id:
			continue
		if not require_same_owner:
			return true
		var source_owner_id := EffectSourceMetaHelperScript.resolve_source_owner_id(effect_instance.meta)
		if source_owner_id.is_empty():
			last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
			return false
		if source_owner_id == required_owner_id:
			return true
	return false
