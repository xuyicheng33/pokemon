extends RefCounted
class_name FieldApplyConflictService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

var rng_service
var context_resolver

func resolve_missing_dependency() -> String:
	if rng_service == null:
		return "rng_service"
	if context_resolver == null:
		return "context_resolver"
	return ""

func resolve_field_kind(field_definition) -> String:
	if field_definition == null:
		return ContentSchemaScript.FIELD_KIND_NORMAL
	var normalized_kind := String(field_definition.field_kind).strip_edges()
	assert(not normalized_kind.is_empty(), "FieldDefinition.field_kind must not be empty for %s" % String(field_definition.id))
	assert(
		normalized_kind == ContentSchemaScript.FIELD_KIND_NORMAL or normalized_kind == ContentSchemaScript.FIELD_KIND_DOMAIN,
		"FieldDefinition.field_kind invalid: %s" % normalized_kind
	)
	return normalized_kind

func should_resolve_domain_clash(challenger_field_definition, incumbent_field_definition) -> bool:
	return resolve_field_kind(challenger_field_definition) == ContentSchemaScript.FIELD_KIND_DOMAIN \
	and resolve_field_kind(incumbent_field_definition) == ContentSchemaScript.FIELD_KIND_DOMAIN

func is_normal_field_blocked_by_domain(challenger_field_definition, incumbent_field_definition) -> bool:
	return resolve_field_kind(challenger_field_definition) == ContentSchemaScript.FIELD_KIND_NORMAL \
	and resolve_field_kind(incumbent_field_definition) == ContentSchemaScript.FIELD_KIND_DOMAIN

func resolve_field_clash(before_field, effect_event, battle_state) -> Dictionary:
	var challenger_creator: String = context_resolver.resolve_field_creator(effect_event)
	var incumbent_creator: String = String(before_field.creator)
	var challenger_mp: int = _resolve_creator_mp(battle_state, challenger_creator)
	var incumbent_mp: int = _resolve_creator_mp(battle_state, incumbent_creator)
	if incumbent_creator == challenger_creator:
		return _build_clash_result(true, true, challenger_creator, incumbent_creator, challenger_mp, incumbent_mp, null)
	if challenger_mp > incumbent_mp:
		return _build_clash_result(true, false, challenger_creator, incumbent_creator, challenger_mp, incumbent_mp, null)
	if challenger_mp < incumbent_mp:
		return _build_clash_result(false, false, challenger_creator, incumbent_creator, challenger_mp, incumbent_mp, null)
	var tie_roll: Variant = rng_service.next_float()
	battle_state.rng_stream_index = rng_service.get_stream_index()
	return _build_clash_result(
		tie_roll >= 0.5,
		false,
		challenger_creator,
		incumbent_creator,
		challenger_mp,
		incumbent_mp,
		tie_roll
	)

func _build_clash_result(challenger_won: bool, same_creator: bool, challenger_creator: String, incumbent_creator: String, challenger_mp: int, incumbent_mp: int, tie_roll) -> Dictionary:
	return {
		"challenger_won": challenger_won,
		"same_creator": same_creator,
		"challenger_creator": challenger_creator,
		"incumbent_creator": incumbent_creator,
		"challenger_mp": challenger_mp,
		"incumbent_mp": incumbent_mp,
		"tie_roll": tie_roll,
	}

func _resolve_creator_mp(battle_state, creator_id: String) -> int:
	if creator_id.is_empty():
		return -1
	var creator_unit = battle_state.get_unit(creator_id)
	if creator_unit == null:
		return -1
	return int(creator_unit.current_mp)
