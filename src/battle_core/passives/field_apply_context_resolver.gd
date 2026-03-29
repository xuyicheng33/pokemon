extends RefCounted
class_name FieldApplyContextResolver

func resolve_field_creator(effect_event) -> String:
	if effect_event != null and effect_event.owner_id != null:
		var owner_id := str(effect_event.owner_id)
		if not owner_id.is_empty():
			return owner_id
	if effect_event != null and effect_event.chain_context != null and effect_event.chain_context.actor_id != null:
		var actor_id := str(effect_event.chain_context.actor_id)
		if not actor_id.is_empty():
			return actor_id
	return ""

func resolve_public_id_or_system(battle_state, source_id: String) -> String:
	if source_id.is_empty():
		return "system"
	var source_unit = battle_state.get_unit(source_id)
	if source_unit != null:
		return source_unit.public_id
	return source_id
