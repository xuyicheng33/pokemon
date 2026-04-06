extends RefCounted
class_name BattleHeaderSnapshotBuilder

const DeepCopyHelperScript := preload("res://src/shared/deep_copy_helper.gd")

static func build_header_snapshot(battle_state, content_index = null) -> Dictionary:
	if battle_state == null:
		return {}
	var initial_field_snapshot: Variant = null
	if battle_state.field_state != null:
		initial_field_snapshot = build_public_field_snapshot(battle_state, content_index)
	return {
		"visibility_mode": battle_state.visibility_mode,
		"prebattle_public_teams": build_prebattle_public_teams(battle_state, content_index),
		"initial_active_public_ids_by_side": build_initial_active_public_ids_by_side(battle_state),
		"initial_field": initial_field_snapshot,
	}

static func build_public_field_snapshot(battle_state, content_index = null) -> Dictionary:
	if battle_state.field_state == null:
		return DeepCopyHelperScript.copy_value({
			"field_id": null,
			"field_kind": null,
			"remaining_turns": null,
			"creator_public_id": null,
			"creator_side_id": null,
		})
	var creator_id := String(battle_state.field_state.creator)
	if creator_id.is_empty():
		return DeepCopyHelperScript.copy_value({
			"field_id": battle_state.field_state.field_def_id,
			"field_kind": null,
			"remaining_turns": battle_state.field_state.remaining_turns,
			"creator_public_id": null,
			"creator_side_id": null,
		})
	var field_kind: Variant = null
	if content_index != null:
		var field_definition = content_index.fields.get(String(battle_state.field_state.field_def_id), null)
		if field_definition != null:
			field_kind = String(field_definition.field_kind)
	var creator_side_id: Variant = null
	var creator_side = battle_state.get_side_for_unit(creator_id)
	if creator_side != null:
		creator_side_id = String(creator_side.side_id)
	return DeepCopyHelperScript.copy_value({
		"field_id": battle_state.field_state.field_def_id,
		"field_kind": field_kind,
		"remaining_turns": battle_state.field_state.remaining_turns,
		"creator_public_id": _resolve_public_id_or_null(battle_state, creator_id),
		"creator_side_id": creator_side_id,
	})

static func build_prebattle_public_teams(battle_state, content_index) -> Array:
	if content_index == null:
		return []
	var side_models: Array = []
	for side_state in battle_state.sides:
		var unit_models: Array = []
		for unit_state in side_state.team_units:
			var unit_definition = content_index.units.get(unit_state.definition_id, null)
			if unit_definition == null:
				continue
			unit_models.append({
				"public_id": unit_state.public_id,
				"definition_id": unit_definition.id,
				"display_name": unit_definition.display_name,
				"level": battle_state.battle_level,
				"combat_type_ids": unit_definition.combat_type_ids,
				"skill_ids": unit_state.regular_skill_ids,
				"ultimate_skill_id": unit_definition.ultimate_skill_id,
				"ultimate_points_required": unit_definition.ultimate_points_required,
				"ultimate_points_cap": unit_definition.ultimate_points_cap,
				"ultimate_point_gain_on_regular_skill_cast": unit_definition.ultimate_point_gain_on_regular_skill_cast,
				"passive_skill_id": unit_definition.passive_skill_id,
				"passive_item_id": unit_definition.passive_item_id,
				"base_stats": {
					"hp": unit_definition.base_hp,
					"attack": unit_definition.base_attack,
					"defense": unit_definition.base_defense,
					"sp_attack": unit_definition.base_sp_attack,
					"sp_defense": unit_definition.base_sp_defense,
					"speed": unit_definition.base_speed,
					"max_mp": unit_definition.max_mp,
					"init_mp": unit_definition.init_mp,
					"regen_per_turn": unit_definition.regen_per_turn,
				},
			})
		unit_models.sort_custom(func(left, right): return String(left.get("public_id", "")) < String(right.get("public_id", "")))
		side_models.append({
			"side_id": side_state.side_id,
			"units": unit_models,
		})
	side_models.sort_custom(func(left, right): return String(left.get("side_id", "")) < String(right.get("side_id", "")))
	return DeepCopyHelperScript.copy_value(side_models)

static func build_initial_active_public_ids_by_side(battle_state) -> Dictionary:
	var active_ids_by_side: Dictionary = {}
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		active_ids_by_side[side_state.side_id] = active_unit.public_id if active_unit != null else null
	return DeepCopyHelperScript.copy_value(active_ids_by_side)

static func _resolve_public_id_or_null(battle_state, source_id: String) -> Variant:
	if source_id.is_empty():
		return null
	var source_unit = battle_state.get_unit(source_id)
	if source_unit != null:
		return source_unit.public_id
	return null
