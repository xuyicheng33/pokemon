extends RefCounted
class_name FieldState

var field_def_id: String = ""
var instance_id: String = ""
var creator: String = ""
var remaining_turns: int = 0
var source_instance_id: String = ""
var source_kind_order: int = 0
var source_order_speed_snapshot: int = 0
var reversible_stat_mod_totals: Dictionary = {}
var pending_success_effect_ids: PackedStringArray = PackedStringArray()
var pending_success_source_instance_id: String = ""
var pending_success_source_kind_order: int = 0
var pending_success_source_order_speed_snapshot: int = 0
var pending_success_chain_context: ChainContext = null

func ensure_reversible_stat_mod_slot(owner_id: String, stat_name: String) -> void:
	if owner_id.is_empty() or stat_name.is_empty():
		return
	var entry_key := _build_reversible_stat_mod_key(owner_id, stat_name)
	if not reversible_stat_mod_totals.has(entry_key):
		reversible_stat_mod_totals[entry_key] = 0

func record_reversible_stat_mod(owner_id: String, stat_name: String, applied_delta: int) -> void:
	if owner_id.is_empty() or stat_name.is_empty() or applied_delta == 0:
		return
	var entry_key := _build_reversible_stat_mod_key(owner_id, stat_name)
	reversible_stat_mod_totals[entry_key] = int(reversible_stat_mod_totals.get(entry_key, 0)) + applied_delta
	if int(reversible_stat_mod_totals[entry_key]) == 0:
		reversible_stat_mod_totals.erase(entry_key)

func consume_reversible_stat_mod(owner_id: String, stat_name: String, requested_delta: int) -> int:
	if owner_id.is_empty() or stat_name.is_empty() or requested_delta == 0:
		return requested_delta
	var entry_key := _build_reversible_stat_mod_key(owner_id, stat_name)
	if not reversible_stat_mod_totals.has(entry_key):
		return requested_delta
	var stored_delta: int = int(reversible_stat_mod_totals.get(entry_key, 0))
	if stored_delta == 0:
		reversible_stat_mod_totals.erase(entry_key)
		return 0
	if sign(stored_delta) == sign(requested_delta):
		return requested_delta
	var bounded_delta := requested_delta
	if abs(requested_delta) > abs(stored_delta):
		bounded_delta = -stored_delta
	var remaining_delta := stored_delta + bounded_delta
	if remaining_delta == 0:
		reversible_stat_mod_totals.erase(entry_key)
	else:
		reversible_stat_mod_totals[entry_key] = remaining_delta
	return bounded_delta

func clear_reversible_stat_mod(owner_id: String, stat_name: String) -> void:
	if owner_id.is_empty() or stat_name.is_empty():
		return
	reversible_stat_mod_totals.erase(_build_reversible_stat_mod_key(owner_id, stat_name))

func _build_reversible_stat_mod_key(owner_id: String, stat_name: String) -> String:
	return "%s|%s" % [owner_id, stat_name]

func to_stable_dict() -> Dictionary:
	var reversible_entries: Array = []
	var sorted_keys: Array = reversible_stat_mod_totals.keys()
	sorted_keys.sort()
	for raw_entry_key in sorted_keys:
		var entry_key := String(raw_entry_key)
		var key_parts := entry_key.split("|")
		reversible_entries.append({
			"owner_id": key_parts[0] if key_parts.size() > 0 else "",
			"stat_name": key_parts[1] if key_parts.size() > 1 else "",
			"delta": int(reversible_stat_mod_totals.get(entry_key, 0)),
		})
	var pending_chain_context_dict: Variant = null
	if pending_success_chain_context != null:
		pending_chain_context_dict = _chain_context_to_stable_dict(pending_success_chain_context)
	return {
		"field_def_id": field_def_id,
		"instance_id": instance_id,
		"creator": creator,
		"remaining_turns": remaining_turns,
		"source_instance_id": source_instance_id,
		"source_kind_order": source_kind_order,
		"source_order_speed_snapshot": source_order_speed_snapshot,
		"reversible_stat_mod_totals": reversible_entries,
		"pending_success_chain_context": pending_chain_context_dict,
		"pending_success_effect_ids": Array(pending_success_effect_ids),
		"pending_success_source_instance_id": pending_success_source_instance_id,
		"pending_success_source_kind_order": pending_success_source_kind_order,
		"pending_success_source_order_speed_snapshot": pending_success_source_order_speed_snapshot,
	}

func _chain_context_to_stable_dict(chain_context: ChainContext) -> Dictionary:
	var dedupe_entries: Array = []
	var dedupe_keys: Array = chain_context.effect_dedupe_keys.keys()
	dedupe_keys.sort()
	for dedupe_key in dedupe_keys:
		dedupe_entries.append({
			"key": String(dedupe_key),
			"value": chain_context.effect_dedupe_keys[dedupe_key],
		})
	return {
		"action_actor_id": chain_context.action_actor_id,
		"action_combat_type_id": chain_context.action_combat_type_id,
		"action_queue_index": chain_context.action_queue_index,
		"action_segment_index": chain_context.action_segment_index,
		"action_segment_total": chain_context.action_segment_total,
		"actor_id": chain_context.actor_id,
		"chain_depth": chain_context.chain_depth,
		"chain_origin": chain_context.chain_origin,
		"command_source": chain_context.command_source,
		"command_type": chain_context.command_type,
		"defer_field_apply_success": chain_context.defer_field_apply_success,
		"effect_dedupe_keys": dedupe_entries,
		"event_chain_id": chain_context.event_chain_id,
		"root_action_id": chain_context.root_action_id,
		"select_deadline_ms": chain_context.select_deadline_ms,
		"select_timeout": chain_context.select_timeout,
		"skill_id": chain_context.skill_id,
		"step_counter": chain_context.step_counter,
		"target_slot": chain_context.target_slot,
		"target_unit_id": chain_context.target_unit_id,
	}
