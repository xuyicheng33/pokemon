extends RefCounted
class_name PowerBonusSourceRegistry

const ZERO_POWER_BONUS_RESOLVER_STRATEGY_PATH := "res://src/battle_core/content/power_bonus_resolver_strategy_zero.gd"
const MP_DIFF_CLAMPED_POWER_BONUS_RESOLVER_STRATEGY_PATH := "res://src/battle_core/content/power_bonus_resolver_strategy_mp_diff_clamped.gd"
const EFFECT_STACK_SUM_POWER_BONUS_RESOLVER_STRATEGY_PATH := "res://src/battle_core/content/power_bonus_resolver_strategy_effect_stack_sum.gd"
const EFFECT_STACK_SUM_POWER_BONUS_CONTRACT_VALIDATOR_PATH := "res://src/battle_core/content/power_bonus_contract_validator_effect_stack_sum.gd"

const MP_DIFF_CLAMPED := "mp_diff_clamped"
const EFFECT_STACK_SUM := "effect_stack_sum"

const SOURCE_DESCRIPTORS := [
	{
		"source": "",
		"resolver_script_path": ZERO_POWER_BONUS_RESOLVER_STRATEGY_PATH,
		"validator_script_path": "",
	},
	{
		"source": MP_DIFF_CLAMPED,
		"resolver_script_path": MP_DIFF_CLAMPED_POWER_BONUS_RESOLVER_STRATEGY_PATH,
		"validator_script_path": "",
	},
	{
		"source": EFFECT_STACK_SUM,
		"resolver_script_path": EFFECT_STACK_SUM_POWER_BONUS_RESOLVER_STRATEGY_PATH,
		"validator_script_path": EFFECT_STACK_SUM_POWER_BONUS_CONTRACT_VALIDATOR_PATH,
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

static func resolver_script_path_for_source(source: String) -> String:
	return String(descriptor_for_source(source).get("resolver_script_path", "")).strip_edges()

static func validator_script_path_for_source(source: String) -> String:
	return String(descriptor_for_source(source).get("validator_script_path", "")).strip_edges()

static func unresolved_validator_sources() -> PackedStringArray:
	var unresolved := PackedStringArray()
	for raw_source in registered_sources():
		var source := String(raw_source)
		var validator_script_path := validator_script_path_for_source(source)
		if validator_script_path.is_empty():
			continue
		if not ResourceLoader.exists(validator_script_path):
			unresolved.append(source)
			continue
		var validator_script = load(validator_script_path)
		var validator = validator_script.new()
		if validator != null and validator.has_method("validate_skill_contract"):
			continue
		unresolved.append(source)
	return unresolved

static func validate_skill_contract(errors: Array, skill_id: String, skill_definition, content_index) -> void:
	var validator_script_path := validator_script_path_for_source(String(skill_definition.power_bonus_source))
	if validator_script_path.is_empty() or not ResourceLoader.exists(validator_script_path):
		return
	var validator_script = load(validator_script_path)
	var validator = validator_script.new()
	if validator == null or not validator.has_method("validate_skill_contract"):
		return
	validator.validate_skill_contract(errors, skill_id, skill_definition, content_index)
