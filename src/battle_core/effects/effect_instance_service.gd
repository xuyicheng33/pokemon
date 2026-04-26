extends RefCounted
class_name EffectInstanceService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "id_factory",
		"source": "id_factory",
		"nested": true,
	},
]

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const EffectInstanceScript := preload("res://src/battle_core/runtime/effect_instance.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EffectSourceMetaHelperScript := preload("res://src/battle_core/effects/effect_source_meta_helper.gd")

var id_factory: IdFactory
var last_invalid_battle_code: Variant = null
var last_apply_skipped: bool = false

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func create_instance(effect_definition, owner_id: String, battle_state: BattleState, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int, meta: Dictionary = {}) -> Variant:
	last_invalid_battle_code = null
	last_apply_skipped = false
	var owner_unit = battle_state.get_unit(owner_id)
	if owner_unit == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return null
	var existing_instance = _find_existing(owner_unit, effect_definition.id)
	match effect_definition.stacking:
		ContentSchemaScript.STACKING_NONE:
			if existing_instance != null:
				last_apply_skipped = true
				return existing_instance
		ContentSchemaScript.STACKING_REFRESH:
			if existing_instance != null:
				existing_instance.remaining = effect_definition.duration
				existing_instance.source_instance_id = source_instance_id
				existing_instance.source_kind_order = source_kind_order
				existing_instance.source_order_speed_snapshot = source_order_speed_snapshot
				existing_instance.meta = meta.duplicate(true)
				last_apply_skipped = false
				return existing_instance
		ContentSchemaScript.STACKING_REPLACE:
			if existing_instance != null:
				owner_unit.effect_instances.erase(existing_instance)
		ContentSchemaScript.STACKING_STACK:
			var matching_instances: Array = _find_matching_instances(owner_unit, effect_definition.id)
			var max_stacks: int = int(effect_definition.max_stacks)
			if max_stacks > 0 and matching_instances.size() >= max_stacks:
				last_apply_skipped = true
				return matching_instances[0]
	var effect_instance = EffectInstanceScript.new()
	effect_instance.instance_id = id_factory.next_id("effect")
	effect_instance.def_id = effect_definition.id
	effect_instance.owner = owner_id
	effect_instance.remaining = effect_definition.duration
	effect_instance.created_turn = battle_state.turn_index
	effect_instance.source_instance_id = source_instance_id
	effect_instance.source_kind_order = source_kind_order
	effect_instance.source_order_speed_snapshot = source_order_speed_snapshot
	effect_instance.persists_on_switch = effect_definition.persists_on_switch
	effect_instance.meta = meta.duplicate(true)
	owner_unit.effect_instances.append(effect_instance)
	return effect_instance

func remove_instance(owner_id: String, effect_definition_id: String, battle_state: BattleState) -> Variant:
	var owner_unit = battle_state.get_unit(owner_id)
	if owner_unit == null:
		return null
	var matching_instances: Array = _find_matching_instances(owner_unit, effect_definition_id)
	if matching_instances.size() != 1:
		return null
	var existing_instance = matching_instances[0]
	owner_unit.effect_instances.erase(existing_instance)
	return existing_instance

func remove_all_instances(owner_id: String, effect_definition_id: String, battle_state: BattleState) -> Array:
	var owner_unit = battle_state.get_unit(owner_id)
	if owner_unit == null:
		return []
	var matching_instances: Array = _find_matching_instances(owner_unit, effect_definition_id)
	if matching_instances.is_empty():
		return []
	for effect_instance in matching_instances:
		owner_unit.effect_instances.erase(effect_instance)
	return matching_instances

func unit_has_persistent_effect(unit_state) -> bool:
	if unit_state == null:
		return false
	for effect_instance in unit_state.effect_instances:
		if bool(effect_instance.persists_on_switch):
			return true
	return false

static func count_matching_effect_instances(unit_state, allowed_definition_ids: PackedStringArray) -> int:
	if unit_state == null or allowed_definition_ids.is_empty():
		return 0
	var allowed_lookup: Dictionary = {}
	for raw_definition_id in allowed_definition_ids:
		var normalized_definition_id := String(raw_definition_id).strip_edges()
		if normalized_definition_id.is_empty():
			continue
		allowed_lookup[normalized_definition_id] = true
	if allowed_lookup.is_empty():
		return 0
	var matching_count := 0
	for effect_instance in unit_state.effect_instances:
		if allowed_lookup.has(String(effect_instance.def_id)):
			matching_count += 1
	return matching_count

func target_satisfies_required_effect(target_unit, effect_definition_id: String, require_same_owner: bool, required_owner_id: String) -> Dictionary:
	if target_unit == null:
		return {"has_match": false, "invalid_battle_code": null}
	for effect_instance in target_unit.effect_instances:
		if String(effect_instance.def_id) != String(effect_definition_id):
			continue
		if not require_same_owner:
			return {"has_match": true, "invalid_battle_code": null}
		var source_owner_id := EffectSourceMetaHelperScript.resolve_source_owner_id(effect_instance.meta)
		if source_owner_id.is_empty():
			return {"has_match": false, "invalid_battle_code": ErrorCodesScript.INVALID_STATE_CORRUPTION}
		if source_owner_id == String(required_owner_id):
			return {"has_match": true, "invalid_battle_code": null}
	return {"has_match": false, "invalid_battle_code": null}

func partition_effects_on_leave(unit_state, leave_reason: String) -> Dictionary:
	if unit_state == null:
		return {"kept_effects": [], "removed_effects": []}
	var kept_effects: Array = []
	var removed_effects: Array = []
	for effect_instance in unit_state.effect_instances:
		if _should_keep_on_leave(effect_instance, leave_reason):
			kept_effects.append(effect_instance)
		else:
			removed_effects.append(effect_instance)
	return {"kept_effects": kept_effects, "removed_effects": removed_effects}

func removed_effect_log_descriptors(removed_effects: Array, content_index: BattleContentIndex) -> Dictionary:
	var descriptors: Array = []
	for effect_instance in removed_effects:
		var effect_definition = content_index.effects.get(effect_instance.def_id) if content_index != null else null
		if effect_definition == null:
			return {"descriptors": [], "invalid_battle_code": ErrorCodesScript.INVALID_EFFECT_DEFINITION}
		descriptors.append({
			"source_instance_id": effect_instance.source_instance_id,
			"def_id": effect_instance.def_id,
			"priority": effect_definition.priority,
		})
	return {"descriptors": descriptors, "invalid_battle_code": null}

static func build_active_effect_public_summaries(unit_state) -> Array:
	if unit_state == null:
		return []
	var summaries: Array = []
	for effect_instance in unit_state.effect_instances:
		summaries.append({
			"effect_definition_id": effect_instance.def_id,
			"remaining": effect_instance.remaining,
			"persists_on_switch": effect_instance.persists_on_switch,
			"__sort_instance_id": effect_instance.instance_id,
		})
	return summaries

func _should_keep_on_leave(effect_instance, leave_reason: String) -> bool:
	if effect_instance == null:
		return false
	if String(leave_reason) == "faint":
		return false
	return bool(effect_instance.persists_on_switch)

func _find_existing(owner_unit, effect_definition_id: String) -> Variant:
	for effect_instance in owner_unit.effect_instances:
		if effect_instance.def_id == effect_definition_id:
			return effect_instance
	return null

func _find_matching_instances(owner_unit, effect_definition_id: String) -> Array:
	var matching_instances: Array = []
	for effect_instance in owner_unit.effect_instances:
		if effect_instance.def_id == effect_definition_id:
			matching_instances.append(effect_instance)
	return matching_instances
