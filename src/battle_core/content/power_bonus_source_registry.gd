extends RefCounted
class_name PowerBonusSourceRegistry

const MP_DIFF_CLAMPED := "mp_diff_clamped"
const EFFECT_STACK_SUM := "effect_stack_sum"
const RESOLVER_KIND_ZERO := "zero"
const RESOLVER_KIND_MP_DIFF_CLAMPED := "mp_diff_clamped"
const RESOLVER_KIND_EFFECT_STACK_SUM := "effect_stack_sum"

const SOURCE_DESCRIPTORS := [
	{
		"source": "",
		"resolver_kind": RESOLVER_KIND_ZERO,
		"validator_kind": "",
	},
	{
		"source": MP_DIFF_CLAMPED,
		"resolver_kind": RESOLVER_KIND_MP_DIFF_CLAMPED,
		"validator_kind": "",
	},
	{
		"source": EFFECT_STACK_SUM,
		"resolver_kind": RESOLVER_KIND_EFFECT_STACK_SUM,
		"validator_kind": EFFECT_STACK_SUM,
	},
]

static func descriptors() -> Array:
	return SOURCE_DESCRIPTORS.duplicate(true)

static func registered_sources() -> PackedStringArray:
	var sources := PackedStringArray()
	for descriptor in SOURCE_DESCRIPTORS:
		sources.append(String(descriptor.get("source", "")))
	return sources

static func descriptor_for_source(source: String) -> Dictionary:
	var normalized_source := String(source).strip_edges()
	for descriptor in SOURCE_DESCRIPTORS:
		if String(descriptor.get("source", "")).strip_edges() == normalized_source:
			return descriptor.duplicate(true)
	return {}

static func resolver_kind_for_source(source: String) -> String:
	return String(descriptor_for_source(source).get("resolver_kind", ""))

static func validate_skill_contract(errors: Array, skill_id: String, skill_definition, content_index) -> void:
	match String(descriptor_for_source(String(skill_definition.power_bonus_source)).get("validator_kind", "")):
		EFFECT_STACK_SUM:
			_validate_effect_stack_sum_contract(errors, skill_id, skill_definition, content_index)

static func _validate_effect_stack_sum_contract(errors: Array, skill_id: String, skill_definition, content_index) -> void:
	var has_any_effect_id := false
	for effect_id in skill_definition.power_bonus_self_effect_ids:
		var normalized_effect_id := String(effect_id).strip_edges()
		if normalized_effect_id.is_empty():
			errors.append("skill[%s].power_bonus_self_effect_ids must not contain empty entry" % skill_id)
			continue
		has_any_effect_id = true
		if not content_index.effects.has(normalized_effect_id):
			errors.append("skill[%s].power_bonus_self_effect_ids missing effect: %s" % [skill_id, normalized_effect_id])
	for effect_id in skill_definition.power_bonus_target_effect_ids:
		var normalized_effect_id := String(effect_id).strip_edges()
		if normalized_effect_id.is_empty():
			errors.append("skill[%s].power_bonus_target_effect_ids must not contain empty entry" % skill_id)
			continue
		has_any_effect_id = true
		if not content_index.effects.has(normalized_effect_id):
			errors.append("skill[%s].power_bonus_target_effect_ids missing effect: %s" % [skill_id, normalized_effect_id])
	if not has_any_effect_id:
		errors.append("skill[%s].effect_stack_sum requires at least one power bonus effect id" % skill_id)
	if int(skill_definition.power_bonus_per_stack) <= 0:
		errors.append("skill[%s].power_bonus_per_stack must be > 0 for effect_stack_sum, got %d" % [skill_id, int(skill_definition.power_bonus_per_stack)])
