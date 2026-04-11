extends SceneTree

const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const ManifestLoaderScript := preload("res://src/shared/formal_character_manifest/formal_character_manifest_loader.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const PowerBonusSourceRegistryScript := preload("res://src/battle_core/content/power_bonus_source_registry.gd")

const FACT_REQUIRED_TARGET_EFFECTS := "required_target_effects"
const FACT_REQUIRED_TARGET_SAME_OWNER := "required_target_same_owner"
const FACT_INCOMING_ACCURACY := "incoming_accuracy"
const FACT_NULLIFY_FIELD_ACCURACY := "nullify_field_accuracy"
const FACT_EFFECT_STACK_SUM := "effect_stack_sum"
const FACT_ONCE_PER_BATTLE := "once_per_battle"
const FACT_PERSISTENT_STAT_STAGES := "persistent_stat_stages"
const FACT_MISSING_HP := "missing_hp"
const FACT_INCOMING_HEAL_FINAL_MOD := "incoming_heal_final_mod"
const FACT_EXECUTE_TARGET_HP_RATIO_LTE := "execute_target_hp_ratio_lte"
const FACT_EXECUTE_REQUIRED_TOTAL_STACKS := "execute_required_total_stacks"
const FACT_DAMAGE_SEGMENTS := "damage_segments"
const FACT_ON_RECEIVE_ACTION_DAMAGE_SEGMENT := "on_receive_action_damage_segment"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: missing output path")
		quit(1)
		return
	var output_path := String(args[0]).strip_edges()
	if output_path.is_empty():
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: empty output path")
		quit(1)
		return
	var manifest_path := ""
	if args.size() >= 2:
		manifest_path = String(args[1]).strip_edges()
	var manifest = FormalCharacterManifestScript.new()
	if manifest == null:
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: missing manifest loader")
		quit(1)
		return
	if not manifest_path.is_empty():
		manifest.manifest_path_override = manifest_path
	var entries_result: Dictionary = manifest.build_character_entries_result()
	if not bool(entries_result.get("ok", false)):
		printerr(
			"EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: %s" % String(entries_result.get("error_message", "unknown error"))
		)
		quit(1)
		return
	var facts_by_character: Dictionary = {}
	var fact_sources_by_character: Dictionary = {}
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: manifest entry must be dictionary")
			quit(1)
			return
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: manifest entry missing character_id")
			quit(1)
			return
		var fact_sources: Dictionary = _collect_character_fact_sources(entry)
		if fact_sources == null:
			return
		var sorted_facts: Array = fact_sources.keys()
		sorted_facts.sort()
		facts_by_character[character_id] = sorted_facts
		fact_sources_by_character[character_id] = _sorted_fact_sources_view(fact_sources)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: cannot open output path: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify({
		"facts_by_character": facts_by_character,
		"fact_sources_by_character": fact_sources_by_character,
	}, "  "))
	file.flush()
	file.close()
	quit(0)

func _collect_character_fact_sources(entry: Dictionary):
	var fact_sources: Dictionary = {}
	for raw_rel_path in entry.get("required_content_paths", []):
		var rel_path := String(raw_rel_path).strip_edges()
		if rel_path.is_empty():
			continue
		var resolved_path := ManifestLoaderScript.normalize_resource_path(rel_path)
		var resource = ResourceLoader.load(resolved_path)
		if resource == null:
			printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: missing resource %s" % resolved_path)
			quit(1)
			return null
		_collect_resource_facts(fact_sources, rel_path, resource)
	return fact_sources

func _collect_resource_facts(fact_sources: Dictionary, rel_path: String, resource) -> void:
	if resource is SkillDefinitionScript:
		_collect_skill_facts(fact_sources, rel_path, resource)
	if resource is EffectDefinitionScript:
		_collect_effect_facts(fact_sources, rel_path, resource)

func _collect_skill_facts(fact_sources: Dictionary, rel_path: String, skill_definition) -> void:
	if String(skill_definition.power_bonus_source) == PowerBonusSourceRegistryScript.EFFECT_STACK_SUM:
		_register_fact(fact_sources, FACT_EFFECT_STACK_SUM, rel_path)
	if bool(skill_definition.once_per_battle):
		_register_fact(fact_sources, FACT_ONCE_PER_BATTLE, rel_path)
	if float(skill_definition.execute_target_hp_ratio_lte) > 0.0:
		_register_fact(fact_sources, FACT_EXECUTE_TARGET_HP_RATIO_LTE, rel_path)
	if int(skill_definition.execute_required_total_stacks) > 0:
		_register_fact(fact_sources, FACT_EXECUTE_REQUIRED_TOTAL_STACKS, rel_path)
	if not skill_definition.damage_segments.is_empty():
		_register_fact(fact_sources, FACT_DAMAGE_SEGMENTS, rel_path)

func _collect_effect_facts(fact_sources: Dictionary, rel_path: String, effect_definition) -> void:
	if not effect_definition.required_target_effects.is_empty():
		_register_fact(fact_sources, FACT_REQUIRED_TARGET_EFFECTS, rel_path)
	if bool(effect_definition.required_target_same_owner):
		_register_fact(fact_sources, FACT_REQUIRED_TARGET_SAME_OWNER, rel_path)
	if effect_definition.trigger_names.has(FACT_ON_RECEIVE_ACTION_DAMAGE_SEGMENT):
		_register_fact(fact_sources, FACT_ON_RECEIVE_ACTION_DAMAGE_SEGMENT, rel_path)
	for payload in effect_definition.payloads:
		_collect_payload_facts(fact_sources, rel_path, payload)

func _collect_payload_facts(fact_sources: Dictionary, rel_path: String, payload) -> void:
	if payload is RuleModPayloadScript:
		match String(payload.mod_kind):
			FACT_INCOMING_ACCURACY:
				_register_fact(fact_sources, FACT_INCOMING_ACCURACY, rel_path)
			FACT_NULLIFY_FIELD_ACCURACY:
				_register_fact(fact_sources, FACT_NULLIFY_FIELD_ACCURACY, rel_path)
			FACT_INCOMING_HEAL_FINAL_MOD:
				_register_fact(fact_sources, FACT_INCOMING_HEAL_FINAL_MOD, rel_path)
	if payload is HealPayloadScript and bool(payload.use_percent) and String(payload.percent_base) == FACT_MISSING_HP:
		_register_fact(fact_sources, FACT_MISSING_HP, rel_path)
	if payload is StatModPayloadScript and String(payload.retention_mode) == "persist_on_switch":
		_register_fact(fact_sources, FACT_PERSISTENT_STAT_STAGES, rel_path)

func _register_fact(fact_sources: Dictionary, fact_id: String, rel_path: String) -> void:
	var sources: Array = fact_sources.get(fact_id, [])
	if sources.has(rel_path):
		return
	sources.append(rel_path)
	fact_sources[fact_id] = sources

func _sorted_fact_sources_view(fact_sources: Dictionary) -> Dictionary:
	var view: Dictionary = {}
	var fact_ids := fact_sources.keys()
	fact_ids.sort()
	for raw_fact_id in fact_ids:
		var fact_id := String(raw_fact_id)
		var sources: Array = fact_sources.get(fact_id, []).duplicate()
		sources.sort()
		view[fact_id] = sources
	return view
