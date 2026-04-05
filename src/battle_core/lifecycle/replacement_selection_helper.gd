extends RefCounted
class_name ReplacementSelectionHelper

func collect_legal_bench_ids(battle_state, side_state) -> PackedStringArray:
	var legal_bench_ids := PackedStringArray()
	for bench_unit_id in side_state.bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit == null or bench_unit.current_hp <= 0:
			continue
		legal_bench_ids.append(bench_unit_id)
	return legal_bench_ids

func find_active_slot_id(side_state, unit_instance_id: String) -> String:
	for slot_id in side_state.active_slots.keys():
		if str(side_state.active_slots[slot_id]) == unit_instance_id:
			return str(slot_id)
	return ""

func select_replacement_unit_id(battle_state, side_state, legal_bench_ids: PackedStringArray, reason: String, replacement_selector) -> String:
	if legal_bench_ids.size() == 1:
		return legal_bench_ids[0]
	if replacement_selector == null:
		return ""
	var selected = replacement_selector.select_replacement(
		battle_state,
		side_state.side_id,
		legal_bench_ids,
		reason,
		battle_state.chain_context
	)
	var selected_unit_id := str(selected) if selected != null else ""
	if selected_unit_id.is_empty() or not legal_bench_ids.has(selected_unit_id):
		return ""
	return selected_unit_id
