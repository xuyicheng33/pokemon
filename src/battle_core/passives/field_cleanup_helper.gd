extends RefCounted
class_name FieldCleanupHelper

func clear_field_state_if_matches(battle_state: BattleState, field_state) -> void:
	if battle_state == null or field_state == null:
		return
	clear_old_field_if_still_active(battle_state, field_state)

func clear_old_field_if_still_active(battle_state: BattleState, field_state) -> void:
	if battle_state == null or field_state == null:
		return
	_remove_field_rule_mods_for_instance(battle_state, String(field_state.instance_id))
	var active_field = battle_state.field_state
	if active_field == null:
		return
	if String(active_field.instance_id) != String(field_state.instance_id):
		return
	battle_state.field_state = null

func _remove_field_rule_mods_for_instance(battle_state: BattleState, field_instance_id: String) -> void:
	if battle_state == null:
		return
	if field_instance_id.is_empty():
		battle_state.field_rule_mod_instances.clear()
		return
	var keep_instances: Array = []
	for rule_mod_instance in battle_state.field_rule_mod_instances:
		var owner_field_instance_id := String(rule_mod_instance.field_instance_id) if rule_mod_instance != null else ""
		var source_instance_id := String(rule_mod_instance.source_instance_id) if rule_mod_instance != null else ""
		if owner_field_instance_id == field_instance_id or source_instance_id == field_instance_id:
			continue
		keep_instances.append(rule_mod_instance)
	battle_state.field_rule_mod_instances = keep_instances
