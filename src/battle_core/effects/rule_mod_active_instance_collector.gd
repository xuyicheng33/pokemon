extends RefCounted
class_name RuleModActiveInstanceCollector

func sorted_active_instances_for_read(battle_state: BattleState, owner_id: String) -> Array:
	var owner_unit = battle_state.get_unit(owner_id)
	if owner_unit == null:
		return []
	var ordered_instances: Array = []
	_append_active_instances(ordered_instances, owner_unit.rule_mod_instances)
	_append_active_instances(ordered_instances, battle_state.field_rule_mod_instances)
	ordered_instances.sort_custom(_sort_rule_mods)
	return ordered_instances

func _append_active_instances(output: Array, instances: Array) -> void:
	for rule_mod_instance in instances:
		if rule_mod_instance.duration_mode == "turns" and rule_mod_instance.remaining <= 0:
			continue
		output.append(rule_mod_instance)

func _sort_rule_mods(left, right) -> bool:
	if left.priority != right.priority:
		return left.priority > right.priority
	if left.source_order_speed_snapshot != right.source_order_speed_snapshot:
		return left.source_order_speed_snapshot > right.source_order_speed_snapshot
	if left.source_kind_order != right.source_kind_order:
		return left.source_kind_order < right.source_kind_order
	if left.source_instance_id != right.source_instance_id:
		return left.source_instance_id < right.source_instance_id
	return left.instance_id < right.instance_id
