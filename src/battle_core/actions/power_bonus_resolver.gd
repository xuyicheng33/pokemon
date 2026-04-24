extends RefCounted
class_name PowerBonusResolver

const PowerBonusSourceRegistryScript := preload("res://src/battle_core/content/power_bonus_source_registry.gd")

var _resolver_instances: Dictionary = {}

static func registered_sources() -> PackedStringArray:
	return PowerBonusSourceRegistryScript.registered_sources()

static func unresolved_registered_sources() -> PackedStringArray:
	var unresolved := PackedStringArray()
	for raw_source in registered_sources():
		var resolver_script_path := PowerBonusSourceRegistryScript.resolver_script_path_for_source(String(raw_source))
		if resolver_script_path.is_empty() or not ResourceLoader.exists(resolver_script_path):
			unresolved.append(String(raw_source))
			continue
		var resolver_script = load(resolver_script_path)
		var resolver = resolver_script.new()
		if resolver != null and resolver.has_method("resolve_power_bonus"):
			continue
		unresolved.append(String(raw_source))
	return unresolved

func resolve_power_bonus(skill_definition, actor, target, actor_mp_after_cost: int, target_mp_before_cast: int) -> int:
	if skill_definition == null:
		return 0
	var resolver = _resolver_for_source(String(skill_definition.power_bonus_source))
	if resolver == null or not resolver.has_method("resolve_power_bonus"):
		return 0
	return int(resolver.resolve_power_bonus(
		skill_definition,
		actor,
		target,
		actor_mp_after_cost,
		target_mp_before_cast
	))

func _resolver_for_source(source: String) -> Variant:
	var normalized_source := source.strip_edges()
	if _resolver_instances.has(normalized_source):
		return _resolver_instances[normalized_source]
	var resolver_script_path := PowerBonusSourceRegistryScript.resolver_script_path_for_source(normalized_source)
	if resolver_script_path.is_empty() or not ResourceLoader.exists(resolver_script_path):
		return null
	var resolver_script = load(resolver_script_path)
	var resolver = resolver_script.new()
	if resolver == null or not resolver.has_method("resolve_power_bonus"):
		return null
	_resolver_instances[normalized_source] = resolver
	return resolver
